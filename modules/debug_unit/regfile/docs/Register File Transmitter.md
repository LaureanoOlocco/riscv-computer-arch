# Register File Transmitter

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2026-02

## Description

Transmits the current program counter followed by all 32 register file entries over UART. Sends the PC first as a 4-byte little-endian word, then sequentially reads and serializes each register (x0 through x31) as 4 bytes each. Asserts `o_done` after the last byte of the last register is transmitted.

## Parameters

| Parameter      | Default | Description                          |
|----------------|:-------:|--------------------------------------|
| `NB_PC`        | `32`    | Width of the program counter.        |
| `NB_REG`       | `32`    | Width of each register value.        |
| `NB_UART_DATA` | `8`     | Width of each UART byte.             |

## Ports

| Name              | Direction | Width          | Description                                          |
|-------------------|:---------:|:--------------:|------------------------------------------------------|
| `o_done`          | Output    | 1              | Asserted after the last register byte is sent.       |
| `o_tx_start`      | Output    | 1              | UART transmitter start pulse.                        |
| `o_wr`            | Output    | 1              | UART FIFO write enable.                              |
| `o_wdata`         | Output    | `NB_UART_DATA` | Byte to write to the UART FIFO.                      |
| `o_regfile_rd`    | Output    | 1              | Register file read enable.                           |
| `o_regfile_raddr` | Output    | 5              | Register file read address.                          |
| `i_start`         | Input     | 1              | Start pulse from `du_master`.                        |
| `i_pc`            | Input     | `NB_PC`        | Current program counter value.                       |
| `i_regfile_data`  | Input     | `NB_REG`       | Data read from the register file.                    |
| `i_tx_done`       | Input     | 1              | UART transmitter done acknowledgment.                |
| `i_rst`           | Input     | 1              | Synchronous active-high reset.                       |
| `clk`             | Input     | 1              | System clock.                                        |

## State Machine

| State      | Description                                                                      |
|------------|----------------------------------------------------------------------------------|
| `IDLE`     | Waits for `i_start`. Resets address counter and byte counter to zero.           |
| `SEND_PC`  | Serializes the 4-byte PC value little-endian, waiting for `i_tx_done` each byte.|
| `READ_REG` | Asserts `o_regfile_rd`; pipelines the read and latches data after 5 sub-cycles. |
| `SEND_REG` | Serializes the latched register value byte-by-byte; loops or terminates.        |

## Behavior

- **Type:** One-hot FSMD with combinational output logic; synchronous active-high reset.
- **Transmission order:** PC → x0 → x1 → … → x31. Total transfer: 4 + 32×4 = 132 bytes.
- **Read pipeline:** In `READ_REG`, `o_regfile_rd` is held high and the 3-bit counter advances each cycle. After 5 cycles the data is latched from `i_regfile_data` and the address is incremented; this pipeline delay accounts for the register file's synchronous read latency.
- **Termination:** After sending x31 (`regfile_addr_reg` wraps to `5'd0`), `o_done` is asserted and the FSM returns to `IDLE`.
- **Byte serialization:** Both `SEND_PC` and `SEND_REG` send bytes LSB-first, waiting for `i_tx_done` before each successive byte.

## Design Notes

- The 3-bit counter is shared between `READ_REG` and `SEND_REG`; it is reset to zero at each state transition, preventing stale counts.
- Termination is detected by the address wrapping to zero rather than comparing to a fixed count of 32, which saves an explicit comparator.
