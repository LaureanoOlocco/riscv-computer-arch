# Debug Unit Top

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-02

## Description

Top-level container for the debug unit subsystem. Instantiates and interconnects all debug submodules — `du_master`, `du_imem_loader`, `du_dmem_rx`, `du_dmem_tx`, `du_regfile_rx`, `du_regfile_tx`, `du_latch_tx`, `du_resp_builder`, and `du_breakpoint` — and exposes a single unified interface to the rest of the SoC. UART TX signals from multiple submodules are OR-gated; the protocol guarantees that only one submodule is active at a time.

## Parameters

| Parameter      | Default | Description                          |
|----------------|:-------:|--------------------------------------|
| `NB_DATA`      | `32`    | Width of data and address buses.     |
| `NB_ADDR`      | `8`     | Width of memory address bus.         |
| `NB_PC`        | `32`    | Width of the program counter.        |
| `NB_REG`       | `32`    | Width of register data.              |
| `NB_UART_DATA` | `8`     | Width of each UART byte.             |
| `N_BKP`        | `4`     | Number of hardware breakpoint slots. |

## Ports

| Name               | Direction | Width          | Description                                        |
|--------------------|:---------:|:--------------:|----------------------------------------------------|
| `o_cpu_enable`     | Output    | 1              | CPU pipeline enable (step / run).                  |
| `o_cpu_reset`      | Output    | 1              | CPU reset pulse.                                   |
| `o_imem_wr`        | Output    | 1              | IMEM write enable.                                 |
| `o_imem_waddr`     | Output    | `NB_ADDR`      | IMEM write address.                                |
| `o_imem_wdata`     | Output    | `NB_DATA`      | IMEM write data.                                   |
| `o_regfile_rd`     | Output    | 1              | Register file debug read enable.                   |
| `o_regfile_raddr`  | Output    | 5              | Register file debug read address.                  |
| `o_regfile_wr`     | Output    | 1              | Register file debug write enable.                  |
| `o_regfile_waddr`  | Output    | 5              | Register file debug write address.                 |
| `o_regfile_wdata`  | Output    | `NB_REG`       | Register file debug write data.                    |
| `o_dmem_rd`        | Output    | 1              | DMEM debug read enable.                            |
| `o_dmem_raddr`     | Output    | `NB_ADDR`      | DMEM debug read address.                           |
| `o_dmem_wr`        | Output    | 1              | DMEM debug write enable.                           |
| `o_dmem_waddr`     | Output    | `NB_ADDR`      | DMEM debug write address.                          |
| `o_dmem_wdata`     | Output    | `NB_DATA`      | DMEM debug write data.                             |
| `o_bkp_hit`        | Output    | 1              | Breakpoint hit signal.                             |
| `o_tx_start`       | Output    | 1              | UART TX start (OR of all active submodules).       |
| `o_uart_rd`        | Output    | 1              | UART RX FIFO read enable.                          |
| `o_uart_wr`        | Output    | 1              | UART TX FIFO write enable.                         |
| `o_uart_wdata`     | Output    | `NB_UART_DATA` | UART TX FIFO write data.                           |
| `i_pc`             | Input     | `NB_PC`        | Current program counter.                           |
| `i_instruction`    | Input     | `NB_DATA`      | Current instruction word.                          |
| `i_regfile_data`   | Input     | `NB_REG`       | Register file read data.                           |
| `i_dmem_data`      | Input     | `NB_DATA`      | Data memory read data.                             |
| `i_ifid_pc`        | Input     | `NB_PC`        | IF/ID pipeline register — PC.                      |
| `i_ifid_instr`     | Input     | `NB_DATA`      | IF/ID pipeline register — instruction.             |
| `i_idex_ctrl`      | Input     | 9              | ID/EX pipeline register — control signals.         |
| `i_idex_rs1_data`  | Input     | `NB_DATA`      | ID/EX pipeline register — rs1 data.                |
| `i_idex_rs2_data`  | Input     | `NB_DATA`      | ID/EX pipeline register — rs2 data.                |
| `i_idex_imm`       | Input     | `NB_DATA`      | ID/EX pipeline register — immediate.               |
| `i_idex_rd_addr`   | Input     | 5              | ID/EX pipeline register — destination address.     |
| `i_idex_rs1_addr`  | Input     | 5              | ID/EX pipeline register — rs1 address.             |
| `i_idex_rs2_addr`  | Input     | 5              | ID/EX pipeline register — rs2 address.             |
| `i_exmem_ctrl`     | Input     | 4              | EX/MEM pipeline register — control signals.        |
| `i_exmem_alu`      | Input     | `NB_DATA`      | EX/MEM pipeline register — ALU result.             |
| `i_exmem_data2`    | Input     | `NB_DATA`      | EX/MEM pipeline register — store data.             |
| `i_exmem_rd_addr`  | Input     | 5              | EX/MEM pipeline register — destination address.    |
| `i_memwb_ctrl`     | Input     | 2              | MEM/WB pipeline register — control signals.        |
| `i_memwb_data`     | Input     | `NB_DATA`      | MEM/WB pipeline register — memory data.            |
| `i_memwb_alu`      | Input     | `NB_DATA`      | MEM/WB pipeline register — ALU result.             |
| `i_memwb_rd_addr`  | Input     | 5              | MEM/WB pipeline register — destination address.    |
| `i_uart_rx_done`   | Input     | 1              | UART byte received pulse.                          |
| `i_uart_rx_data`   | Input     | `NB_UART_DATA` | Received UART byte.                                |
| `i_uart_rx_empty`  | Input     | 1              | UART RX FIFO empty flag.                           |
| `i_uart_tx_done`   | Input     | 1              | UART TX done acknowledgment.                       |
| `i_rst`            | Input     | 1              | Synchronous active-high reset.                     |
| `clk`              | Input     | 1              | System clock.                                      |

## Architecture

The top module is purely structural — no combinational or sequential logic beyond the OR-gating of shared UART TX signals:

```
                          ┌─────────────┐
  UART RX ──────────────► │  du_master  │──── start pulses ──►  submodules
                          └─────────────┘◄─── done signals ──── submodules
                               │
              ┌────────────────┴──────────────────────────┐
              ▼                ▼            ▼              ▼
       du_imem_loader   du_dmem_rx   du_regfile_rx   du_breakpoint
       du_dmem_tx       du_regfile_tx  du_latch_tx   du_resp_builder
              │                │            │              │
              └────────── OR ──┴── OR ──────┴──── OR ──────┘
                               │
                          UART TX outputs
```

## Design Notes

- OR-gating of `o_tx_start`, `o_uart_wr`, and `o_uart_wdata` is safe because `du_master` enforces mutual exclusion — only one submodule holds a `start` pulse at any given time.
- All pipeline latch inputs are wired directly from the CPU subsystem without registering at this level; timing closure is the responsibility of the CPU clock domain.
