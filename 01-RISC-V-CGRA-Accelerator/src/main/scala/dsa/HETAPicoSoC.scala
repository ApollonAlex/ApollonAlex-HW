package dsa

import chisel3._
import scala.collection.mutable

/** PicoRV32 -> 64-KiB RAM / HETA MMIO -> ControlUnitV2 -> CGRA.
  *
  * FPGA board independent. The HETA CGRA external streaming inputs/outputs
  * are retained for now. LSU hostInterface is NOT yet CPU-addressable.
  */
class HETAPicoSoC(attrs: mutable.Map[String, Any]) extends Module {
  val param = dsa.template.CgraParam(attrs)
  import param._

  val io = IO(new Bundle {
    val in          = Input(Vec(numIn, UInt(dataWidth.W)))
    val out         = Output(Vec(numOut, UInt(dataWidth.W)))
    val cpu_trap    = Output(Bool())
    val bus_fault   = Output(Bool())
    val signature   = Output(UInt(32.W))
    val cpu_mem_valid = Output(Bool())
    val cpu_mem_ready = Output(Bool())
    val cpu_mem_instr = Output(Bool())
    val cpu_mem_addr  = Output(UInt(32.W))
    val cpu_mem_wdata = Output(UInt(32.W))
    val cpu_mem_wstrb = Output(UInt(4.W))
  })

  val cpu = Module(new PicoRV32Core)
  val bus = Module(new PicoRV32HETABus)
  val ram = Module(new HETAProgramRAM)
  val heta = Module(new CU_CGRATop_MMIO(attrs))

  cpu.io.clk := clock
  cpu.io.resetn := !reset.asBool
  cpu.io.irq := 0.U
  cpu.io.pcpi_wr := false.B
  cpu.io.pcpi_rd := 0.U
  cpu.io.pcpi_wait := false.B
  cpu.io.pcpi_ready := false.B

  bus.io.mem_valid := cpu.io.mem_valid
  bus.io.mem_instr := cpu.io.mem_instr
  bus.io.mem_addr  := cpu.io.mem_addr
  bus.io.mem_wdata := cpu.io.mem_wdata
  bus.io.mem_wstrb := cpu.io.mem_wstrb
  cpu.io.mem_ready := bus.io.mem_ready
  cpu.io.mem_rdata := bus.io.mem_rdata

  ram.io.clk       := clock
  ram.io.resetn    := !reset.asBool
  ram.io.mem_valid := bus.io.ram_valid
  ram.io.mem_addr  := bus.io.ram_addr
  ram.io.mem_wdata := bus.io.ram_wdata
  ram.io.mem_wstrb := bus.io.ram_wstrb
  bus.io.ram_ready := ram.io.mem_ready
  bus.io.ram_rdata := ram.io.mem_rdata

  heta.io.req_valid := bus.io.heta_req_valid
  heta.io.req_write := bus.io.heta_req_write
  heta.io.req_addr  := bus.io.heta_req_addr
  heta.io.req_wdata := bus.io.heta_req_wdata
  heta.io.req_wstrb := bus.io.heta_req_wstrb
  bus.io.heta_resp_ready := heta.io.resp_ready
  bus.io.heta_resp_rdata := heta.io.resp_rdata
  heta.io.in := io.in
  io.out := heta.io.out

  io.cpu_trap := cpu.io.trap
  io.bus_fault := bus.io.bus_fault
  io.signature := ram.io.signature
  io.cpu_mem_valid := cpu.io.mem_valid
  io.cpu_mem_ready := cpu.io.mem_ready
  io.cpu_mem_instr := cpu.io.mem_instr
  io.cpu_mem_addr  := cpu.io.mem_addr
  io.cpu_mem_wdata := cpu.io.mem_wdata
  io.cpu_mem_wstrb := cpu.io.mem_wstrb
}
