# RISC-V Computer Architecture

Verilog/SystemVerilog implementation of an RV32I RISC-V system for FPGA, with a 5-stage pipelined CPU, UART debug unit, and host-side tools to assemble, load, and control firmware.

The repository already includes per-module documentation under `modules/**/docs`. This page is the main project entry point.

## Features

- 32-bit RV32I CPU with IF, ID, EX, MEM, and WB pipeline stages.
- Data hazard handling with stalls and forwarding in ID, EX, and MEM.
- Control hazard handling for jumps and branches resolved in ID.
- Instruction and data memories based on `block_ram`.
- UART debug unit for firmware loading, run, halt, step, register reads, memory reads, and breakpoints.
- UART 115200 8N1 by default, with RX/TX FIFOs.
- Nexys 4 FPGA top-level with constraints in `boards/Nexys-4-Master.xdc`.
- Python scripts for RV32I assembly and debug-unit communication.

## Repository Layout

| Path | Contents |
|------|----------|
| `modules/cpu/` | CPU, ALU, control, hazards, pipeline registers, memories, muxes, PC, and register file. |
| `modules/debug_unit/` | Debug controller, UART protocol, IMEM loader, register/memory reads, and breakpoints. |
| `modules/uart/` | UART RX/TX, baud-rate generator, FIFO, and legacy interface. |
| `modules/top/` | CPU, debug unit, UART, FIFOs, and FPGA wrapper integration. |
| `scripts/` | Simple RV32I assembler and debug/loading clients. |
| `code/asm/` | Example RV32I assembly programs. |
| `code/bin/` | Example binaries generated for IMEM loading. |
| `boards/` | Board constraints. |
| `docs/` | Architecture, protocol, and development documentation. |

## Recommended Reading

- [System Architecture](docs/ARCHITECTURE.md)
- [UART Debug Protocol](docs/DEBUG_PROTOCOL.md)
- [Development, Simulation, and FPGA](docs/DEVELOPMENT.md)

## Requirements

- Python 3.
- `pyserial` for the UART client: `python3 -m pip install pyserial`.
- Icarus Verilog or another Verilog/SystemVerilog-compatible simulator for testbenches.
- Vivado for FPGA synthesis and implementation.
- In Vivado, generate a `clk_wiz_0` IP with a 100 MHz input and a 75 MHz output, because `modules/top/top_wrapper.v` instantiates it.

## Quick Start

Assemble an RV32I program:

```bash
python3 scripts/parser.py code/asm/test_program.s code/bin/test_program.bin -v
```

Open the UART debug shell:

```bash
python3 scripts/debug_client.py /dev/ttyUSB0 115200
```

Useful shell commands:

```text
sync
load code/bin/test_program.bin
reset
run
halt
step 5
rr 255
rm 0x00
bkp 0x20
clr 0x20
```

On Windows, firmware can be loaded with:

```bash
python scripts/load_program_windows.py COM3 115200 code/bin/test_program.bin
```

## Simulation

There is no global `Makefile` in the repository. Testbenches are compiled by listing the testbench and its RTL dependencies. Simple ALU example:

```bash
mkdir -p build
iverilog -g2012 -o build/alu_tb.vvp modules/cpu/alu/rtl/alu.v modules/cpu/alu/tests/alu_tb.sv
vvp build/alu_tb.vvp
```

For integrated testbenches, add every RTL module instantiated by the DUT. See [Development, Simulation, and FPGA](docs/DEVELOPMENT.md) for more detail.

## FPGA Top Level

The board top-level is `modules/top/top_wrapper.v`.

Main flow:

1. `top_wrapper` receives the 100 MHz board clock, uses `clk_wiz_0` to generate 75 MHz, and synchronizes reset/UART RX.
2. `top` instantiates the baud-rate generator, UART RX/TX, FIFOs, and `cpu_subsystem`.
3. `cpu_subsystem` integrates `cpu_core` with `debug_unit_top`.
4. The host communicates over USB-UART using `scripts/debug_client.py`.

## Current Status and Limitations

- `WRITE_REG` and `WRITE_MEM` exist in the RTL protocol, but they are not connected at `cpu_subsystem/cpu_core` level; the Python client reports them as unsupported.
- `READ_LATCH` exists in RTL and transmits 45 bytes with the pipeline registers, but the current Python shell does not expose an interactive command for it.
- The debug unit uses `NB_ADDR = 8` by default for debug addresses, while IMEM/DMEM use `IMEM_ADDR_WIDTH = 10` and `DMEM_ADDR_WIDTH = 10` by default. This gives direct debug access to the first 256 words of 1024-word memories.
- `step N` enables the CPU for N pipeline cycles. Advancing one full instruction from IF to WB usually requires 5 steps.
