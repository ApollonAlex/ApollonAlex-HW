package dsa

import chisel3._
import chisel3.util.HasBlackBoxResource

/** Physical PicoRV32 RTL core (not a CPU emulator).
  *
  * The unmodified upstream Verilog must be installed at:
  *   src/main/resources/picorv32.v
  * This wrapper uses the native valid/ready memory port, RV32I and no IRQ/PCPI.
  */
class PicoRV32Core extends BlackBox with HasBlackBoxResource {
  override def desiredName: String = "picorv32"
  val io = IO(new Bundle {
    val clk       = Input(Clock())
    val resetn    = Input(Bool())
    val trap      = Output(Bool())
    val mem_valid = Output(Bool())
    val mem_instr = Output(Bool())
    val mem_ready = Input(Bool())
    val mem_addr  = Output(UInt(32.W))
    val mem_wdata = Output(UInt(32.W))
    val mem_wstrb = Output(UInt(4.W))
    val mem_rdata = Input(UInt(32.W))
    val irq       = Input(UInt(32.W))
    val pcpi_wr   = Input(Bool())
    val pcpi_rd   = Input(UInt(32.W))
    val pcpi_wait = Input(Bool())
    val pcpi_ready= Input(Bool())
  })
  addResource("/picorv32.v")
}
