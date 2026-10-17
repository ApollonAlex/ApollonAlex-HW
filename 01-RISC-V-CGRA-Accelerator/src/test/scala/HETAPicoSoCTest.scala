package dsa

import chisel3.iotesters.{Driver, PeekPokeTester}
import spec.CGRASpec

/** Requires Verilator and upstream picorv32.v BlackBox resource.
  * The PASS marker is written by RISC-V firmware, NOT by this testbench.
  */
class HETAPicoSoCTester(dut: HETAPicoSoC) extends PeekPokeTester(dut) {
  for (i <- 0 until dut.io.in.length) poke(dut.io.in(i), 0)
  // Keep the previously known input values available at the CGRA ports.
  for ((port, value) <- Seq(5 -> 1, 1 -> 1, 7 -> 3,
                             8 -> 4, 4 -> 2, 3 -> 3)) {
    if (port < dut.io.in.length) poke(dut.io.in(port), value)
  }

  val success = BigInt("48455441", 16) // ASCII 'HETA'
  val failure1 = BigInt("bad00001", 16)
  val failure2 = BigInt("bad00002", 16)
  var sig: BigInt = 0
  var mmioStartWrites = 0
  var mmioRunWrites = 0
  var mmioStatusReads = 0
  var cycles = 0

  while (cycles < 12000 && sig == 0) {
    if (peek(dut.io.bus_fault) != 0) {
      throw new RuntimeException("CPU bus fault at cycle " + cycles +
        ", addr=0x" + peek(dut.io.cpu_mem_addr).toString(16))
    }
    if (peek(dut.io.cpu_trap) != 0) {
      throw new RuntimeException("PicoRV32 trap at cycle " + cycles)
    }
    val valid = peek(dut.io.cpu_mem_valid) != 0
    val ready = peek(dut.io.cpu_mem_ready) != 0
    val addr = peek(dut.io.cpu_mem_addr)
    val wstrb = peek(dut.io.cpu_mem_wstrb)
    if (valid && ready) {
      if (addr == BigInt("40000000", 16) && wstrb != 0) mmioStartWrites += 1
      if (addr == BigInt("40000008", 16) && wstrb != 0) mmioRunWrites += 1
      if (addr == BigInt("40000004", 16) && wstrb == 0) mmioStatusReads += 1
    }
    step(1)
    sig = peek(dut.io.signature)
    cycles += 1
  }
  println(s"CPU cycles=$cycles, start writes=$mmioStartWrites, " +
    s"run writes=$mmioRunWrites, status reads=$mmioStatusReads, " +
    s"signature=0x${sig.toString(16)}")
  assert(sig != failure1 && sig != failure2,
    "Firmware explicitly signaled an MMIO error")
  assert(sig == success, "CPU firmware did not signal PASS")
  assert(mmioStartWrites == 1, "Expected exactly one CPU START write")
  assert(mmioRunWrites == 1, "Expected exactly one CPU RUN_CYCLES write")
  assert(mmioStatusReads > 0, "Expected CPU STATUS polling")
  println("PASS: genuine PicoRV32 RV32I firmware configured, started, and polled HETA")
}

object HETAPicoSoCTest extends App {
  CGRASpec.loadSpec("src/main/resources/cgra_spec.json")
  val verilatorArgs = Array("--backend-name", "verilator")
  Driver.execute(args ++ verilatorArgs,
    () => new HETAPicoSoC(CGRASpec.attrs)) { dut =>
      new HETAPicoSoCTester(dut)
  }
}
