# Response Builder

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-02

## Description

Formats and serializes a 5-byte response frame over UART: one status byte followed by a 32-bit data payload (little-endian). Inputs are latched on `i_valid` and streamed one byte at a time. Asserts `o_done` after the last byte is transmitted.

## Parameters

| Parameter      | Default | Description                    |
|----------------|:-------:|--------------------------------|
| `NB_UART_DATA` | `8`     | Width of each UART byte.       |
| `NB_DATA`      | `32`    | Width of the data payload.     |

## Ports

| Name        | Direction | Width          | Description                                         |
|-------------|:---------:|:--------------:|-----------------------------------------------------|
| `o_done`    | Output    | 1              | Asserted for one cycle after the last byte is sent. |
| `o_tx_start`| Output    | 1              | UART transmitter start pulse.                       |
| `o_wr`      | Output    | 1              | UART FIFO write enable.                             |
| `o_wdata`   | Output    | `NB_UART_DATA` | Byte to write to the UART FIFO.                     |
| `i_valid`   | Input     | 1              | Latch pulse — captures `i_status` and `i_data`.     |
| `i_status`  | Input     | `NB_UART_DATA` | Response status byte (byte 0 of the frame).         |
| `i_data`    | Input     | `NB_DATA`      | Response data payload (bytes 1–4, little-endian).   |
| `i_tx_done` | Input     | 1              | UART transmitter done acknowledgment.               |
| `i_rst`     | Input     | 1              | Synchronous active-high reset.                      |
| `clk`       | Input     | 1              | System clock.                                       |

## Frame Layout

| Byte | Content                  |
|:----:|--------------------------|
| `0`  | Status byte (`i_status`) |
| `1`  | `i_data[7:0]`            |
| `2`  | `i_data[15:8]`           |
| `3`  | `i_data[23:16]`          |
| `4`  | `i_data[31:24]`          |

## State Machine

| State       | Description                                                         |
|-------------|---------------------------------------------------------------------|
| `IDLE`      | Waits for `i_valid`. Latches `i_status` and `i_data` on assertion. |
| `SEND_BYTE` | Drives `o_wr`, `o_tx_start`, and `o_wdata` for the current byte.   |
| `WAIT_TX`   | Waits for `i_tx_done`. Advances counter or returns to `IDLE`.      |

## Behavior

- **Type:** Registered FSM; outputs are registered (`output reg`).
- **Latching:** `i_status` and `i_data` are captured into `status_reg` / `data_reg` on the `i_valid` pulse in `IDLE`, preventing glitches during serialization.
- **Done pulse:** `o_done` is asserted for one cycle after the fifth byte (`byte_cnt == 4`) is acknowledged by `i_tx_done`.
