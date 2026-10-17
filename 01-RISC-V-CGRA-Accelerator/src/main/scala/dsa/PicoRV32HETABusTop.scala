package dsa

import chisel3._
import scala.collection.mutable

/** First full HETA datapath integration with a PicoRV32-native *bus port*.
  *
  * NOT YET A PROCESSOR-BASED SoC: connect picorv32.v and a RAM at the ports.
  * CGRA input/output ports remain externally driven as in the regression test.
  */
class PicoRV32HETABusTop(attrs: mutable.Map[String, Any]) extends Module {
  val param = dsa.template.CgraParam(attrs)
  import param._

  val io = IO(new Bundle {
    val mem_valid = Input(Bool())
    val mem_instr = Input(Bool())
    val mem_addr  = Input(UInt(32.W))
    val mem_wdata = Input(UInt(32.W))
    val mem_wstrb = Input(UInt(4.W))
    val mem_ready = Output(Bool())
    val mem_rdata = Output(UInt(32.W))
    val bus_fault = Output(Bool())

    val ram_valid = Output(Bool())
    val ram_instr = Output(Bool())
    val ram_addr  = Output(UInt(32.W))
    val ram_wdata = Output(UInt(32.W))
    val ram_wstrb = Output(UInt(4.W))
    val ram_ready = Input(Bool())
    val ram_rdata = Input(UInt(32.W))

    val in  = Input(Vec(numIn, UInt(dataWidth.W)))
    val out = Output(Vec(numOut, UInt(dataWidth.W)))
  })

  val bus = Module(new PicoRV32HETABus)
  val heta = Module(new CU_CGRATop_MMIO(attrs))

  bus.io.mem_valid := io.mem_valid
  bus.io.mem_instr := io.mem_instr
  bus.io.mem_addr  := io.mem_addr
  bus.io.mem_wdata := io.mem_wdata
  bus.io.mem_wstrb := io.mem_wstrb
  io.mem_ready := bus.io.mem_ready
  io.mem_rdata := bus.io.mem_rdata
  io.bus_fault := bus.io.bus_fault

  heta.io.req_valid := bus.io.heta_req_valid
  heta.io.req_write := bus.io.heta_req_write
  heta.io.req_addr  := bus.io.heta_req_addr
  heta.io.req_wdata := bus.io.heta_req_wdata
  heta.io.req_wstrb := bus.io.heta_req_wstrb
  bus.io.heta_resp_ready := heta.io.resp_ready
  bus.io.heta_resp_rdata := heta.io.resp_rdata

  io.ram_valid := bus.io.ram_valid
  io.ram_instr := bus.io.ram_instr
  io.ram_addr  := bus.io.ram_addr
  io.ram_wdata := bus.io.ram_wdata
  io.ram_wstrb := bus.io.ram_wstrb
  bus.io.ram_ready := io.ram_ready
  bus.io.ram_rdata := io.ram_rdata

  heta.io.in := io.in
  io.out := heta.io.out
}
