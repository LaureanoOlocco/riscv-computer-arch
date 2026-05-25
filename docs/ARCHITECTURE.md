# System Architecture

This document summarizes how the main project blocks are integrated. Detailed per-module documentation is available under `modules/**/docs`.

## Overview

```text
Host PC
  |
  | USB-UART 115200 8N1
  v
top_wrapper
  |
  v
top
  |-- baud_rate_gen
  |-- uart_rx -> RX FIFO
  |-- TX FIFO -> uart_tx
  `-- cpu_subsystem
        |-- cpu_core
        `-- debug_unit_top
```

The system runs from an internal 75 MHz clock. On FPGA, `top_wrapper` expects a 100 MHz board clock and uses the `clk_wiz_0` IP to generate the 75 MHz clock used by the rest of the design.

## Top-Level Layers

| Module | Path | Responsibility |
|--------|------|----------------|
| `top_wrapper` | `modules/top/top_wrapper.v` | FPGA wrapper, clock wizard, combined reset, and synchronizers. |
| `top` | `modules/top/top.v` | Physical UART, FIFOs, and connection to `cpu_subsystem`. |
| `cpu_subsystem` | `modules/top/cpu_subsystem.v` | Integrates CPU and debug unit, arbitrates shared signals, and registers observability paths. |
| `cpu_core` | `modules/cpu/hazard/rtl/cpu_core.v` | 5-stage pipelined RV32I CPU. |
| `debug_unit_top` | `modules/debug_unit/top/rtl/debug_unit_top.v` | Debug subsystem and UART response multiplexing. |

## CPU

`cpu_core` implements an RV32I CPU with 5 pipeline stages:

| Stage | Main Function |
|-------|---------------|
| IF | PC, IMEM read, and `PC + 4` calculation. |
| ID | Decode, register file, immediate generator, jumps, branches, and ID forwarding. |
| EX | ALU, ALU control, and EX forwarding. |
| MEM | DMEM access and store-data forwarding. |
| WB | Writeback selection into the register file. |

The CPU includes hazard handling:

- Load-use stall with `hazard_detection_unit`.
- ID forwarding for branches and JALR.
- EX forwarding for ALU operands.
- MEM forwarding for store data.
- IF/ID flush for taken branches and jumps.

## Memories

Instruction memory and data memory use `block_ram`.

| Memory | Default Parameter | Default Capacity | CPU Access | Debug Access |
|--------|-------------------|------------------|------------|--------------|
| IMEM | `IMEM_ADDR_WIDTH = 10` | 1024 32-bit words | Instruction reads | Firmware-load writes |
| DMEM | `DMEM_ADDR_WIDTH = 10` | 1024 32-bit words | Load/store | Debug reads |

The debug unit uses `NB_ADDR = 8` by default. `cpu_subsystem` extends that address to the internal IMEM/DMEM widths, so the host can access the first 256 words by default.

## Debug Unit

The debug unit receives commands over UART and controls the CPU without requiring an external JTAG debugger.

Main features:

- Load firmware into IMEM.
- Run, halt, and reset the CPU.
- Execute a configurable number of pipeline cycles.
- Read individual registers or dump PC + all registers.
- Read data memory.
- Set and clear PC breakpoints.
- Serialize pipeline registers through `du_latch_tx`.

`cpu_subsystem` registers CPU observability signals before forwarding them to `debug_unit_top` to help timing closure. When the debug unit needs to inspect state, it keeps the CPU halted through `o_cpu_enable`.

## UART

The host-FPGA link uses UART 115200 8N1 by default.

RX flow:

```text
i_uart_rx -> uart_rx -> RX FIFO -> debug_unit_top
```

TX flow:

```text
debug_unit_top -> TX FIFO -> uart_tx -> o_uart_tx
```

`debug_unit_top` OR-gates several internal TX sources. This is safe because `du_master` guarantees mutual exclusion: only one debug transmitter is active at a time.

## FPGA

The documented target board is Nexys 4. `boards/Nexys-4-Master.xdc` defines:

| Port | Pin | Use |
|------|-----|-----|
| `clock` | `E3` | 100 MHz board clock. |
| `i_rst` | `U9` | Active-high physical reset. |
| `i_uart_rx` | `C4` | RX from USB-UART. |
| `o_uart_tx` | `D4` | TX to USB-UART. |
