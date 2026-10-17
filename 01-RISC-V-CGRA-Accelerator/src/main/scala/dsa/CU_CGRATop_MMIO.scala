package dsa

import chisel3._
import scala.collection.mutable

/** Intermediate CGRA wrapper exposing an MMIO register-slave interface.
  *
  * This intentionally does NOT connect HETA LSU hostInterface to the CPU.
  * All LSU host requests are tied off explicitly to make the current
  * limitation visible and avoid the original DontCare driver.
  *
  * The req_addr port receives a byte offset (not a full CPU physical address).
  */
class CU_CGRATop_MMIO(attrs: mutable.Map[String, Any], numCfg: Int = 30,
                      memFile: String = "config.mem") extends Module {
  val param = dsa.template.CgraParam(attrs)
  import param._

  val io = IO(new Bundle {
    val req_valid = Input(Bool())
    val req_write = Input(Bool())
    val req_addr = Input(UInt(8.W))
    val req_wdata = Input(UInt(32.W))
    val req_wstrb = Input(UInt(4.W))
    val resp_ready = Output(Bool())
    val resp_rdata = Output(UInt(32.W))
    val in = Input(Vec(numIn, UInt(dataWidth.W)))
    val out = Output(Vec(numOut, UInt(dataWidth.W)))
  })

  val cgra = Module(new CGRA(attrs, dumpIR = false))
  val cu = Module(new ControlUnitV2(cfgAddrWidth, cfgDataWidth, numCfg,
                                     cols, rows, memFile))
  val regs = Module(new HETAHostAdapter(numCfg, maxII))

  regs.io.req_valid := io.req_valid
  regs.io.req_write := io.req_write
  regs.io.req_addr := io.req_addr
  regs.io.req_wdata := io.req_wdata
  regs.io.req_wstrb := io.req_wstrb
  io.resp_ready := regs.io.resp_ready
  io.resp_rdata := regs.io.resp_rdata

  cu.io.start := regs.io.start
  cu.io.clear_done := regs.io.clear_done
  cu.io.run_cycles := regs.io.run_cycles
  regs.io.busy := cu.io.busy
  regs.io.done := cu.io.done
  regs.io.in_config := cu.io.in_config
  regs.io.in_flush := cu.io.in_flush
  regs.io.in_execute := cu.io.in_execute

  cgra.io.cfg_en := cu.io.cfg_en
  cgra.io.cfg_addr := cu.io.cfg_addr
  cgra.io.cfg_data := cu.io.cfg_data
  cgra.io.en := cu.io.en
  cgra.io.in := io.in
  io.out := cgra.io.out

  // Safe inactive defaults. LSU read_data.bits is produced by the LSU;
  // its valid/ready behavior still needs redesign for CPU read transactions.
  for (i <- 0 until 2 * rows) {
    cgra.io.hostInterface(i).read_addr := 0.U
    cgra.io.hostInterface(i).read_data.ready := false.B
    cgra.io.hostInterface(i).write_addr := 0.U
    cgra.io.hostInterface(i).write_data.valid := false.B
    cgra.io.hostInterface(i).write_data.bits := 0.U
    cgra.io.hostInterface(i).cycle := 0.U
  }
}
