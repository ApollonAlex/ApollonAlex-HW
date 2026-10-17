# RISC-V Controlled CGRA Accelerator

## Overview
This project is part of my diploma thesis at the University of Patras. It focuses on integrating a RISC-V processor with a Coarse-Grained Reconfigurable Array (CGRA) accelerator through a custom Control Unit and Memory-Mapped I/O (MMIO) interface.

## Main Components
- **PicoRV32:** RISC-V processor core.
- **Control Unit:** Manages CGRA configuration and execution.
- **MMIO Interface:** Enables software-based control of the accelerator.
- **CGRA:** Reconfigurable hardware architecture for accelerating computations.
- **Functional Verification:** Simulation and testing of the integrated system.

## Technologies
- Chisel / Scala
- Verilog
- RISC-V
- FPGA Design
- C / Assembly

## Project Status
The current implementation has been functionally verified through simulation. FPGA implementation is planned as a subsequent development stage.

The underlying CGRA framework is a private dependency and is not included in this repository.
