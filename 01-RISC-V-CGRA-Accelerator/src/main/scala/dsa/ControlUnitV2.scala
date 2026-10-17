package dsa

import chisel3._
import chisel3.util._
import chisel3.util.experimental.loadMemoryFromFile

/** Repeatable, finite-execution replacement for the ORIGINAL ControlUnit.
  * Does NOT alter HETA configuration word/address encoding.
  *
  * START accepted only when idle. Each invocation emits exactly numCfg
  * configuration words, waits (2*rows+6) flush cycles, enables CGRA for
  * runCycles cycles, then raises sticky DONE until next START/CLEAR_DONE.
  *
  * Execution-cycle count is a provisional completion contract: validate it
  * with the HETA benchmark latency and output drain before FPGA measurements.
  */
class ControlUnitV2(
    cfgAddrWidth: Int,
    cfgDataWidth: Int,
    numCfg: Int,
    cols: Int,
    rows: Int,
    memFile: String
) extends Module {
  require(cfgAddrWidth > 0 && cfgDataWidth > 0)
  require(numCfg > 0 && cols > 0 && rows > 0)

  val io = IO(new Bundle {
    val start = Input(Bool())
    val clear_done = Input(Bool())
    val run_cycles = Input(UInt(32.W))
    val busy = Output(Bool())
    val done = Output(Bool())
    val in_config = Output(Bool())
    val in_flush = Output(Bool())
    val in_execute = Output(Bool())
    val cfg_en = Output(Bool())
    val cfg_addr = Output(UInt(cfgAddrWidth.W))
    val cfg_data = Output(UInt(cfgDataWidth.W))
    val en = Output(Vec(cols + 2, Bool()))
  })

  val wordWidth = cfgAddrWidth + cfgDataWidth
  val mem = Mem(numCfg, UInt(wordWidth.W))
  loadMemoryFromFile(mem, memFile)

  val sIdle :: sConfig :: sFlush :: sRun :: Nil = Enum(4)
  val state = RegInit(sIdle)
  val cfgIndex = RegInit(0.U(math.max(1, log2Ceil(numCfg)).W))
  val flushCycles = 2 * rows + 6
  val flushIndex = RegInit(0.U(math.max(1, log2Ceil(flushCycles)).W))
  val runIndex = RegInit(0.U(32.W))
  val requestedRunCycles = RegInit(1.U(32.W))
  val doneReg = RegInit(false.B)

  io.busy := state =/= sIdle
  io.done := doneReg
  io.in_config := state === sConfig
  io.in_flush := state === sFlush
  io.in_execute := state === sRun

  val word = mem(cfgIndex)
  io.cfg_en := state === sConfig
  io.cfg_addr := Mux(io.cfg_en, word(wordWidth - 1, cfgDataWidth), 0.U)
  io.cfg_data := Mux(io.cfg_en, word(cfgDataWidth - 1, 0), 0.U)
  io.en := VecInit(Seq.fill(cols + 2)(state === sRun))

  when(io.clear_done) { doneReg := false.B }

  switch(state) {
    is(sIdle) {
      when(io.start) {
        requestedRunCycles := Mux(io.run_cycles === 0.U, 1.U, io.run_cycles)
        cfgIndex := 0.U
        flushIndex := 0.U
        runIndex := 0.U
        doneReg := false.B
        state := sConfig
      }
    }
    is(sConfig) {
      when(cfgIndex === (numCfg - 1).U) {
        cfgIndex := 0.U
        state := sFlush
      }.otherwise {
        cfgIndex := cfgIndex + 1.U
      }
    }
    is(sFlush) {
      when(flushIndex === (flushCycles - 1).U) {
        flushIndex := 0.U
        state := sRun
      }.otherwise {
        flushIndex := flushIndex + 1.U
      }
    }
    is(sRun) {
      when(runIndex === requestedRunCycles - 1.U) {
        runIndex := 0.U
        state := sIdle
        doneReg := true.B
      }.otherwise {
        runIndex := runIndex + 1.U
      }
    }
  }
}
