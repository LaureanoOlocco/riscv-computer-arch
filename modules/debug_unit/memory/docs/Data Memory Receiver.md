# Data Memory Receiver

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-02

## Description

Receives four consecutive UART bytes following a debug write command, assembles them into a 32-bit little-endian word, and performs a single synchronous write to data memory. The target address is supplied by `du_master` at the moment the start pulse is issued. Asserts `o_done` for one cycle after the write is completed.

## Parameters

| Parameter      | Default | Description                       |
|----------------|:-------:|-----------------------------------|
| `NB_DATA`      | `32`    | Width of the memory data bus.     |
| `NB_ADDR`      | `8`     | Width of the memory address bus.  |
| `NB_UART_DATA` | `8`     | Width of each UART byte.          |

## Ports

| Name           | Direction | Width          | Description                                          |
|----------------|:---------:|:--------------:|------------------------------------------------------|
| `o_done`       | Output    | 1              | Asserted for one cycle after the memory write.       |
| `o_dmem_wr`    | Output    | 1              | Data memory write enable.                            |
| `o_dmem_waddr` | Output    | `NB_ADDR`      | Data memory write address.                           |
| `o_dmem_wdata` | Output    | `NB_DATA`      | Data memory write data.                              |
| `i_start`      | Input     | 1              | Start pulse from `du_master`.                        |
| `i_waddr`      | Input     | `NB_DATA`      | Write address (full 32-bit; truncated to `NB_ADDR`). |
| `i_rx_done`    | Input     | 1              | UART byte received pulse.                            |
| `i_rx_data`    | Input     | `NB_UART_DATA` | Received UART byte.                                  |
| `i_rst`        | Input     | 1              | Synchronous active-high reset.                       |
| `clk`          | Input     | 1              | System clock.                                        |

## State Machine

| State       | Description                                                              |
|-------------|--------------------------------------------------------------------------|
| `IDLE`      | Waits for `i_start`. Latches address and resets word/counter on entry.  |
| `RECV_DATA` | Accumulates 4 bytes from UART into `word_reg` (little-endian order).    |
| `WRITE_MEM` | Asserts `o_dmem_wr` and `o_done` for one cycle, then returns to `IDLE`. |

## Behavior

- **Type:** One-hot FSMD with combinational output logic; synchronous active-high reset.
- **Byte assembly:** Byte 0 maps to `word[7:0]`, byte 1 to `word[15:8]`, and so on. The 2-bit `byte_cnt` wraps naturally to track position.
- **Address truncation:** Only the lower `NB_ADDR` bits of `i_waddr` are used, allowing the master to supply a full 32-bit address without width-matching logic.
- **Done pulse:** `o_done` is asserted simultaneously with `o_dmem_wr` in `WRITE_MEM` and is de-asserted on the next cycle when the FSM returns to `IDLE`.
