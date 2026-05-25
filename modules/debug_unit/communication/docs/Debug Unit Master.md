# Debug Unit Master

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2026-05

## Description

Central command dispatcher for the debug unit. Receives single-byte commands over UART, decodes them, and orchestrates all debug submodules: instruction memory loading, data memory read/write, register file read/write, pipeline latch dump, CPU control (step/run/reset), and breakpoint management. Issues start pulses to the appropriate submodule and waits for done acknowledgment before returning to idle.

## Parameters

| Parameter      | Default | Description                          |
|----------------|:-------:|--------------------------------------|
| `NB_DATA`      | `32`    | Width of data and address buses.     |
| `NB_ADDR`      | `8`     | Width of memory address bus.         |
| `NB_PC`        | `32`    | Width of the program counter.        |
| `NB_REG`       | `32`    | Width of register data.              |
| `NB_UART_DATA` | `8`     | Width of each UART byte.             |
| `N_BKP`        | `4`     | Number of breakpoint slots.          |

## Ports

| Name                  | Direction | Width          | Description                                          |
|-----------------------|:---------:|:--------------:|------------------------------------------------------|
| `o_imem_start`        | Output    | 1              | Start pulse to `du_imem_loader`.                     |
| `o_dmem_rx_start`     | Output    | 1              | Start pulse to `du_dmem_rx`.                         |
| `o_dmem_tx_start`     | Output    | 1              | Start pulse to `du_dmem_tx`.                         |
| `o_regfile_rx_start`  | Output    | 1              | Start pulse to `du_regfile_rx`.                      |
| `o_regfile_tx_start`  | Output    | 1              | Start pulse to `du_regfile_tx`.                      |
| `o_latch_tx_start`    | Output    | 1              | Start pulse to `du_latch_tx`.                        |
| `o_resp_valid`        | Output    | 1              | Valid pulse to `du_resp_builder`.                    |
| `o_resp_status`       | Output    | `NB_UART_DATA` | Status byte forwarded to `du_resp_builder`.          |
| `o_resp_data`         | Output    | `NB_DATA`      | Data payload forwarded to `du_resp_builder`.         |
| `o_cpu_enable`        | Output    | 1              | CPU pipeline enable (step or run mode).              |
| `o_cpu_reset`         | Output    | 1              | CPU reset pulse.                                     |
| `o_bkp_set`           | Output    | 1              | Set breakpoint pulse.                                |
| `o_bkp_clr`           | Output    | 1              | Clear breakpoint pulse.                              |
| `o_bkp_addr`          | Output    | `NB_DATA`      | Breakpoint address to set or clear.                  |
| `o_dmem_waddr`        | Output    | `NB_DATA`      | Write address forwarded to `du_dmem_rx`.             |
| `o_regfile_waddr`     | Output    | 5              | Write address forwarded to `du_regfile_rx`.          |
| `o_uart_rd`           | Output    | 1              | UART FIFO RX read enable.                            |
| `i_uart_rx_done`      | Input     | 1              | UART byte received.                                  |
| `i_uart_rx_data`      | Input     | `NB_UART_DATA` | Received UART byte.                                  |
| `i_uart_rx_empty`     | Input     | 1              | UART RX FIFO empty flag.                             |
| `i_imem_done`         | Input     | 1              | Done acknowledgment from `du_imem_loader`.           |
| `i_dmem_rx_done`      | Input     | 1              | Done acknowledgment from `du_dmem_rx`.               |
| `i_dmem_tx_done`      | Input     | 1              | Done acknowledgment from `du_dmem_tx`.               |
| `i_regfile_rx_done`   | Input     | 1              | Done acknowledgment from `du_regfile_rx`.            |
| `i_regfile_tx_done`   | Input     | 1              | Done acknowledgment from `du_regfile_tx`.            |
| `i_latch_tx_done`     | Input     | 1              | Done acknowledgment from `du_latch_tx`.              |
| `i_resp_done`         | Input     | 1              | Done acknowledgment from `du_resp_builder`.          |
| `i_bkp_hit`           | Input     | 1              | Breakpoint hit signal from `du_breakpoint`.          |
| `i_pc`                | Input     | `NB_PC`        | Current program counter.                             |
| `i_rst`               | Input     | 1              | Synchronous active-high reset.                       |
| `clk`                 | Input     | 1              | System clock.                                        |

## Command Set

| Command Byte | Operation                                          |
|:------------:|----------------------------------------------------|
| `0x01`       | Load instruction memory (`du_imem_loader`).        |
| `0x02`       | Dump data memory (`du_dmem_tx`).                   |
| `0x03`       | Write data memory word (`du_dmem_rx`).             |
| `0x04`       | Dump register file (`du_regfile_tx`).              |
| `0x05`       | Write register file entry (`du_regfile_rx`).       |
| `0x06`       | Dump pipeline latches (`du_latch_tx`).             |
| `0x07`       | Single-step CPU (one clock enable pulse).          |
| `0x08`       | Run CPU continuously until breakpoint or halt.     |
| `0x09`       | Reset CPU.                                         |
| `0x0A`       | Set breakpoint at address received next.           |
| `0x0B`       | Clear breakpoint at address received next.         |

## Behavior

- **Type:** Registered FSM. All outputs registered; synchronous active-high reset.
- **Command flow:** In `IDLE`, the master reads one byte from the UART RX FIFO, decodes it, and transitions to the corresponding dispatch state. It issues a one-cycle start pulse, then waits in a `WAIT` state until the submodule asserts its done signal.
- **Address reception:** Commands that require an address (dmem write, regfile write, breakpoint set/clear) include additional receive states to assemble the 4-byte (or 1-byte for regfile) address before issuing the start pulse.
- **CPU enable:** In step mode the master asserts `o_cpu_enable` for one cycle; in run mode it holds it high until a breakpoint hit is detected.

## Design Notes

- All submodule start signals are one-cycle pulses derived from FSM state transitions, preventing repeated triggers.
- The master does not arbitrate simultaneous commands; only one operation is active at a time.
