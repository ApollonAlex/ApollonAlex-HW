package dsa

import chisel3._

/** Routes the native PicoRV32 memory interface to a HETA MMIO slave or to RAM.
  *
  * Address space (physical BYTE addresses):
  *   0x00000000..0x0000ffff  RAM (64 KiB window; backing RAM is external)
  *   0x40000000..0x400000ff  HETA MMIO registers
  *
  * All other addresses, instruction accesses to MMIO, and misaligned MMIO
  * accesses are intentionally NOT acknowledged; bus_fault is asserted to
  * aid debugging. The PicoRV32 native bus has no error response signal.
  *
  * For READS, mem_wstrb=0. For WRITES, mem_wstrb specifies byte enables.
  * This is a *combinational router*, not a memory and not a CPU.
  */
class PicoRV32HETABus extends Module {
  val io = IO(new Bundle {
    // Native PicoRV32 memory bus
    val mem_valid = Input(Bool())
    val mem_instr = Input(Bool())
    val mem_addr  = Input(UInt(32.W))
    val mem_wdata = Input(UInt(32.W))
    val mem_wstrb = Input(UInt(4.W))
    val mem_ready = Output(Bool())
    val mem_rdata = Output(UInt(32.W))
    val bus_fault = Output(Bool())

    // HETAHostAdapter register slave (byte offset)
    val heta_req_valid = Output(Bool())
    val heta_req_write = Output(Bool())
    val heta_req_addr  = Output(UInt(8.W))
    val heta_req_wdata = Output(UInt(32.W))
    val heta_req_wstrb = Output(UInt(4.W))
    val heta_resp_ready = Input(Bool())
    val heta_resp_rdata = Input(UInt(32.W))

    // External RAM slave (full 32-bit byte address)
    val ram_valid = Output(Bool())
    val ram_instr = Output(Bool())
    val ram_addr  = Output(UInt(32.W))
    val ram_wdata = Output(UInt(32.W))
    val ram_wstrb = Output(UInt(4.W))
    val ram_ready = Input(Bool())
    val ram_rdata = Input(UInt(32.W))
  })

  val addressIsRAM  = io.mem_addr(31, 16) === 0.U(16.W)
  val addressIsHETA = io.mem_addr(31, 8) === "h400000".U(24.W)
  val aligned       = io.mem_addr(1, 0) === 0.U
  val selectHETA = addressIsHETA && !io.mem_instr && aligned
  val selectRAM  = addressIsRAM

  io.bus_fault := io.mem_valid && !selectRAM && !selectHETA

  io.heta_req_valid := io.mem_valid && selectHETA
  io.heta_req_write := io.mem_wstrb.orR
  io.heta_req_addr  := io.mem_addr(7, 0)
  io.heta_req_wdata := io.mem_wdata
  io.heta_req_wstrb := io.mem_wstrb

  io.ram_valid := io.mem_valid && selectRAM
  io.ram_instr := io.mem_instr
  io.ram_addr  := io.mem_addr
  io.ram_wdata := io.mem_wdata
  io.ram_wstrb := io.mem_wstrb

  io.mem_ready := Mux(io.mem_valid && selectHETA, io.heta_resp_ready,
                  Mux(io.mem_valid && selectRAM, io.ram_ready, false.B))
  io.mem_rdata := Mux(io.mem_valid && selectHETA, io.heta_resp_rdata,
                  Mux(io.mem_valid && selectRAM, io.ram_rdata, 0.U(32.W)))
}
