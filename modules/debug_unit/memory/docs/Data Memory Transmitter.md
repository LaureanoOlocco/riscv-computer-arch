# Data Memory Transmitter

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-02

## Description

Performs a full sequential dump of data memory over UART. Starting at address 0, reads each 32-bit word and serializes it as four bytes in little-endian order. Stops after the address counter wraps back to zero (i.e., all `2^NB_ADDR` locations have been sent). Asserts `o_done` after the last byte of the last word is transmitted.

## Parameters

| Parameter      | Default | Description                        |
|----------------|:-------:|------------------------------------|
| `NB_DATA`      | `32`    | Width of the memory data bus.      |
| `NB_ADDR`      | `8`     | Width of the memory address bus.   |
| `NB_UART_DATA` | `8`     | Width of each UART byte.           |

## Ports

| Name          | Direction | Width          | Description                                          |
|---------------|:---------:|:--------------:|------------------------------------------------------|
| `o_done`      | Output    | 1              | Asserted after the last word of the dump is sent.    |
| `o_tx_start`  | Output    | 1              | UART transmitter start pulse.                        |
| `o_wr`        | Output    | 1              | UART FIFO write enable.                              |
| `o_wdata`     | Output    | `NB_UART_DATA` | Byte to write to the UART FIFO.                      |
| `o_mem_rd`    | Output    | 1              | Memory read enable.                                  |
| `o_mem_raddr` | Output    | `NB_ADDR`      | Memory read address.                                 |
| `i_start`     | Input     | 1              | Start pulse from `du_master`.                        |
| `i_mem_data`  | Input     | `NB_DATA`      | Word read from data memory.                          |
| `i_tx_done`   | Input     | 1              | UART transmitter done acknowledgment.                |
| `i_rst`       | Input     | 1              | Synchronous active-high reset.                       |
| `clk`         | Input     | 1              | System clock.                                        |

## State Machine

| State      | Description                                                                     |
|------------|---------------------------------------------------------------------------------|
| `IDLE`     | Waits for `i_start`. Address counter starts at zero.                           |
| `READ_MEM` | Asserts `o_mem_rd` on the first sub-cycle; latches `i_mem_data` after 5 cycles.|
| `SEND_WORD`| Serializes the latched word byte-by-byte, waiting for `i_tx_done` between each.|

## Behavior

- **Type:** One-hot FSMD with a 3-bit internal counter used in both `READ_MEM` and `SEND_WORD`.
- **Read pipeline:** `o_mem_rd` is asserted only on sub-cycle 0 of `READ_MEM`. The data is latched into `rx_data_reg` at sub-cycle 4, and the address is incremented at the same time.
- **Byte serialization:** In `SEND_WORD`, bytes are sent LSB-first (bytes 0–3 correspond to `data[7:0]` through `data[31:24]`), waiting for `i_tx_done` between consecutive bytes.
- **Termination:** The dump ends when the address counter rolls over to zero after sending all words. `o_done` is asserted at that point.

## Design Notes

- The 3-bit counter serves a dual role: it pipelines the memory read latency in `READ_MEM` and sequences the four byte transmissions in `SEND_WORD`. The same reset-to-zero logic applies on transition between these states.
- Because termination is detected by an address wrap-around, the number of words dumped is always exactly `2^NB_ADDR`.
