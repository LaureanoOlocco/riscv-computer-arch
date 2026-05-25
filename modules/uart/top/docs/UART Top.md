# UART Top

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-09

## Description

Top-level integrator for the standalone UART + ALU subsystem. Instantiates and connects `baud_rate_gen`, `uart_rx`, `uart_tx`, two `fifo` buffers (RX and TX), `interface_uart`, and `alu`. Used as a self-contained test bench to validate UART framing and ALU operation independently of the RISC-V pipeline.

## Parameters

| Parameter      | Default       | Description                                    |
|----------------|:-------------:|------------------------------------------------|
| `NB_OP_CODE`   | `6`           | ALU opcode width.                              |
| `NB_DATA`      | `8`           | UART byte width.                               |
| `SM_TICK`      | `16`          | Oversampling ratio (ticks per bit period).     |
| `NB_ADDRESS`   | `4`           | FIFO address width (depth = `2^NB_ADDRESS`).   |
| `NB_COUNT`     | `3`           | Byte-within-word counter width.                |
| `NB_REG`       | `32`          | ALU operand and result width.                  |
| `BAUD_RATE`    | `115_200`     | Target baud rate in bps.                       |
| `CLK_FREQ`     | `100_000_000` | System clock frequency in Hz.                  |
| `NB_UART_OUT`  | `2`           | Width of the combined UART output bus.         |
| `NB_COUNTER`   | `9`           | Baud rate generator counter width.             |

## Ports

| Name       | Direction | Width          | Description                                |
|------------|:---------:|:--------------:|--------------------------------------------|
| `o_uart`   | Output    | `NB_UART_OUT`  | Combined UART output (TX line + extras).   |
| `i_tx`     | Output    | 1              | TX serial line output (re-exported).       |
| `i_rx`     | Input     | 1              | RX serial line input.                      |
| `i_rst`    | Input     | 1              | Synchronous active-high reset.             |
| `clock`    | Input     | 1              | System clock.                              |

## Internal Signal Routing

```
clock ──► baud_rate_gen ──► o_tick ──────────────────► uart_rx
                                 └──────────────────► uart_tx

i_rx ──► uart_rx ──► rx_data/rx_done ──► fifo_rx ──► interface_uart
                                                           │
                                                    alu ◄──┘
                                                     │
interface_uart ──► fifo_tx ──► uart_tx ──► o_tx ──► o_uart
```

## Submodule Instances

| Instance         | Module          | Role                                        |
|------------------|-----------------|---------------------------------------------|
| `u_baud_rate_gen`| `baud_rate_gen` | Generates the oversampling tick.            |
| `u_alu`          | `alu`           | Performs the arithmetic/logic operation.    |
| `u_uart_rx`      | `uart_rx`       | Deserializes the incoming bit stream.       |
| `u_uart_tx`      | `uart_tx`       | Serializes the outgoing byte stream.        |
| `u_fifo_rx`      | `fifo`          | Buffers received bytes from `uart_rx`.      |
| `u_fifo_tx`      | `fifo`          | Buffers bytes to be sent by `uart_tx`.      |
| `u_interface`    | `interface_uart`| Protocol controller and ALU orchestrator.  |

## Design Notes

- This top module is a standalone integration vehicle for the UART and ALU; it is not part of the RISC-V SoC hierarchy. In the full system, `debug_unit_top` and `cpu_subsystem` replace this module's role.
- The `o_uart` bus aggregates the TX line and any additional diagnostic signals into a single output for easy FPGA pin assignment.
