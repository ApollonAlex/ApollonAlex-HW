package dsa

import chisel3._
import chisel3.util.HasBlackBoxResource

/** 64 KiB byte-write RAM with registered read data and one-cycle handshake.
  * Verilog definition: src/main/resources/HETAProgramRAM.v
  * Init file: firmware.hex must be available in the simulator working directory.
  */
class HETAProgramRAM extends BlackBox with HasBlackBoxResource {
  val io = IO(new Bundle {
    val clk       = Input(Clock())
    val resetn    = Input(Bool())
    val mem_valid = Input(Bool())
    val mem_addr  = Input(UInt(32.W))
    val mem_wdata = Input(UInt(32.W))
    val mem_wstrb = Input(UInt(4.W))
    val mem_ready = Output(Bool())
    val mem_rdata = Output(UInt(32.W))
    val signature = Output(UInt(32.W))
  })
  addResource("/HETAProgramRAM.v")
}
