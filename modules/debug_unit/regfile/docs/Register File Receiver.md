# Register File Receiver

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-02

## Description

Receives four consecutive UART bytes following a debug register-write command, assembles them into a 32-bit little-endian word, and writes it to the specified register file entry. The target register address is supplied by `du_master` at the moment the start pulse is issued. Asserts `o_done` for one cycle after the write is completed.

## Parameters

| Parameter      | Default | Description                    |
|----------------|:-------:|--------------------------------|
| `NB_DATA`      | `32`    | Width of the register data.    |
| `NB_UART_DATA` | `8`     | Width of each UART byte.       |

## Ports

| Name              | Direction | Width          | Description                                        |
|-------------------|:---------:|:--------------:|----------------------------------------------------|
| `o_done`          | Output    | 1              | Asserted for one cycle after the register write.   |
| `o_regfile_wr`    | Output    | 1              | Register file write enable.                        |
| `o_regfile_waddr` | Output    | 5              | Register file write address.                       |
| `o_regfile_wdata` | Output    | `NB_DATA`      | Register file write data.                          |
| `i_start`         | Input     | 1              | Start pulse from `du_master`.                      |
| `i_waddr`         | Input     | 5              | Register address from `du_master`.                 |
| `i_rx_done`       | Input     | 1              | UART byte received pulse.                          |
| `i_rx_data`       | Input     | `NB_UART_DATA` | Received UART byte.                                |
| `i_rst`           | Input     | 1              | Synchronous active-high reset.                     |
| `clk`             | Input     | 1              | System clock.                                      |

## State Machine

| State       | Description                                                              |
|-------------|--------------------------------------------------------------------------|
| `IDLE`      | Waits for `i_start`. Latches `i_waddr` and resets word/counter on entry.|
| `RECV_DATA` | Accumulates 4 bytes from UART into `word_reg` (little-endian order).    |
| `WRITE_REG` | Asserts `o_regfile_wr` and `o_done` for one cycle, returns to `IDLE`.   |

## Behavior

- **Type:** One-hot FSMD with combinational output logic; synchronous active-high reset.
- **Byte assembly:** Byte 0 maps to `word[7:0]`, byte 1 to `word[15:8]`, and so on. The 2-bit `byte_cnt` tracks position within the 4-byte word.
- **Address latching:** `i_waddr` is captured into `addr_reg` on `i_start`, ensuring the write address remains stable throughout reception.
- **Done pulse:** `o_done` is asserted simultaneously with `o_regfile_wr` in `WRITE_REG` and de-asserted on the next cycle.
