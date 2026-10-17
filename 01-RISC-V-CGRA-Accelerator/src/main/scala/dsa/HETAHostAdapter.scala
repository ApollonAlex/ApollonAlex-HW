package dsa

import chisel3._
import chisel3.util._

/** Small MMIO register block for a future PicoRV32/other RISC-V bus decoder.
  *
  * This is a *register slave*, NOT a PicoRV32 memory router: `req_addr` is
  * the 8-bit byte OFFSET after a top-level decoder has selected this slave.
  * One req_valid cycle with resp_ready = 1 constitutes one transaction.
  * 32-bit accesses only; byte-enable writes are supported for RUN_CYCLES.
  *
  * Register map:
  * 0x00 CTRL       W: bit0=START, bit1=CLEAR_DONE
  * 0x04 STATUS     R: bit0=busy, bit1=done, bit2=config,
  *                   bit3=flush, bit4=execute
  * 0x08 RUN_CYCLES R/W: number of CGRA-enabled cycles (>=1)
  * 0x0c CFG_WORDS  R: number of configuration words in the ROM
  * 0x10 VERSION    R: 0x00010000 (prototype revision 1.0)
  *
  * Does not implement an LSU data transfer interface. That will be a separate
  * work item after hostInterface read timing is verified.
  */
class HETAHostAdapter(numCfg: Int, defaultRunCycles: Int) extends Module {
  require(numCfg > 0 && defaultRunCycles > 0)

  val io = IO(new Bundle {
    val req_valid  = Input(Bool())
    val req_write  = Input(Bool())
    val req_addr   = Input(UInt(8.W))
    val req_wdata  = Input(UInt(32.W))
    val req_wstrb  = Input(UInt(4.W))
    val resp_ready = Output(Bool())
    val resp_rdata = Output(UInt(32.W))

    val start       = Output(Bool())
    val clear_done  = Output(Bool())
    val run_cycles  = Output(UInt(32.W))
    val busy        = Input(Bool())
    val done        = Input(Bool())
    val in_config   = Input(Bool())
    val in_flush    = Input(Bool())
    val in_execute  = Input(Bool())
  })

  val runCycles = RegInit(defaultRunCycles.U(32.W))
  val access = io.req_valid // selected/decoded by the top-level bus router
  val write = access && io.req_write

  // Zero-wait-state register slave. The master must lower req_valid after an
  // acknowledged transaction, as PicoRV32 does after mem_ready.
  io.resp_ready := access
  io.start := write && io.req_addr === "h00".U && io.req_wstrb(0) && io.req_wdata(0) && !io.busy
  io.clear_done := write && io.req_addr === "h00".U && io.req_wstrb(0) && io.req_wdata(1)

  val writeRun = write && io.req_addr === "h08".U
  val mergedBytes = Wire(Vec(4, UInt(8.W)))
  for (i <- 0 until 4) {
    mergedBytes(i) := Mux(writeRun && io.req_wstrb(i),
      io.req_wdata(8 * i + 7, 8 * i), runCycles(8 * i + 7, 8 * i))
  }
  val mergedRun = Cat(mergedBytes.reverse)
  when(writeRun) {
    // Treat zero as one so every command completes in finite time.
    runCycles := Mux(mergedRun === 0.U, 1.U, mergedRun)
  }
  io.run_cycles := runCycles

  val status = Cat(0.U(27.W), io.in_execute, io.in_flush, io.in_config,
    io.done, io.busy)
  io.resp_rdata := MuxLookup(io.req_addr, 0.U(32.W), Seq(
    "h00".U -> 0.U(32.W),
    "h04".U -> status,
    "h08".U -> runCycles,
    "h0c".U -> numCfg.U(32.W),
    "h10".U -> "h00010000".U(32.W)
  ))
}
