# Piccolo Lightweight Block Cipher – VHDL

## Overview
This project focuses on the RTL design and implementation of the Piccolo ultra-lightweight block cipher using VHDL, supporting both 80-bit and 128-bit encryption keys.

The architecture processes 64-bit data blocks and supports both encryption and decryption operations.

## Main Components
- **FSM:** Controls data loading, encryption/decryption operations, and round execution.
- **Key Schedulers:** Generate whitening keys and round keys for 80-bit and 128-bit configurations.
- **Encryption Datapath:** Implements the initial, iterative, and final rounds.
- **F-Function & S-Box:** Perform nonlinear substitution and diffusion operations.
- **Round Permutation:** Rearranges data between encryption rounds.
- **Testbench:** Validates the design through functional simulation.

## Technologies & Tools
- VHDL
- RTL Design
- ModelSim / QuestaSim
- Xilinx Vivado
- FPGA Design Flow

## Verification & Implementation
The design was simulated using ModelSim for both encryption and decryption with 80-bit and 128-bit keys.

RTL synthesis and implementation analysis were performed using Xilinx Vivado.
