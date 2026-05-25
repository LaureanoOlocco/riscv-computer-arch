# UART Interface

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-09

## Description

Protocol controller for the standalone ALU-over-UART test bench. Receives two 32-bit operands and a 6-bit opcode framed between start (`0xFB`) and end (`0xFD`) delimiters, forwards them to the ALU, and streams the 32-bit result back over UART. Handles framing errors by sending a fixed error word (`0xFEFEFEFE`).

## Parameters

| Parameter    | Default | Description                               |
|--------------|:-------:|-------------------------------------------|
| `NB_DATA`    | `8`     | Width of each UART byte.                  |
| `NB_REG`     | `32`    | Width of operands and ALU result.         |
| `NB_OP_CODE` | `6`     | Width of the ALU opcode.                  |
| `NB_COUNT`   | `3`     | Width of the byte-within-word counter.    |

## Ports

| Name             | Direction | Width        | Description                                         |
|------------------|:---------:|:------------:|-----------------------------------------------------|
| `o_tx_start`     | Output    | 1            | UART TX start pulse.                                |
| `o_read`         | Output    | 1            | UART RX FIFO read enable.                           |
| `o_write`        | Output    | 1            | UART TX FIFO write enable.                          |
| `o_fifo_tx_rd`   | Output    | 1            | TX FIFO read enable (feeds `uart_tx`).              |
| `o_alu_out`      | Output    | `NB_DATA`    | Current TX byte to the UART TX FIFO.                |
| `o_alu_data_a`   | Output    | `NB_REG`     | Operand A forwarded to the ALU.                     |
| `o_alu_data_b`   | Output    | `NB_REG`     | Operand B forwarded to the ALU.                     |
| `o_alu_op_code`  | Output    | `NB_OP_CODE` | Opcode forwarded to the ALU.                        |
| `i_alu_out`      | Input     | `NB_REG`     | ALU result.                                         |
| `i_rx_data`      | Input     | `NB_DATA`    | Byte read from the UART RX FIFO.                    |
| `i_rx_done`      | Input     | 1            | RX FIFO non-empty / byte available.                 |
| `i_rx_empty`     | Input     | 1            | RX FIFO empty flag.                                 |
| `i_fifo_tx_empty`| Input     | 1            | TX FIFO empty flag.                                 |
| `i_tx_done`      | Input     | 1            | UART TX done tick.                                  |
| `i_rst`          | Input     | 1            | Synchronous active-high reset.                      |
| `clock`          | Input     | 1            | System clock.                                       |

## Frame Format

```
[0xFB] [A byte 0] [A byte 1] [A byte 2] [A byte 3]
       [B byte 0] [B byte 1] [B byte 2] [B byte 3]
       [opcode]
[0xFD]
```

All multi-byte fields are little-endian. The interface validates the start and end delimiters; a missing `0xFD` triggers the error state.

## State Machine

| State              | Description                                                      |
|--------------------|------------------------------------------------------------------|
| `STATE_IDLE`       | Waits for start delimiter `0xFB`.                               |
| `STATE_DATA_A`     | Receives 4 bytes into `alu_data_a_reg` (little-endian).         |
| `STATE_DATA_B`     | Receives 4 bytes into `alu_data_b_reg` (little-endian).         |
| `STATE_DATA_OP`    | Receives 1 byte as the opcode.                                  |
| `STATE_END_RX`     | Checks for end delimiter `0xFD`; transitions to flush or error. |
| `STATE_FLUSH_FIFO` | Drains any remaining bytes from the RX FIFO.                    |
| `STATE_FIFO_OUT`   | Latches the ALU result and begins output serialization.         |
| `STATE_SEND`       | Serializes the 4-byte result to the TX FIFO.                    |
| `STATE_ERROR`      | Sends `0xFEFEFEFE` and returns to `STATE_IDLE`.                 |

## Behavior

- **Type:** Registered FSM; synchronous active-high reset.
- **Reception:** Bytes are accumulated using `data_count_reg` to track position within each multi-byte field. `NB_CNT = NB_REG / NB_DATA = 4` bytes per operand.
- **Error handling:** If the byte following the opcode is not `0xFD`, the FSM enters `STATE_ERROR`, transmits the error word, and returns to idle.
- **Transmission:** The ALU result is serialized byte-by-byte using the same `data_count_reg` counter, sending LSB first.

## Design Notes

- This module is used in the standalone UART + ALU integration test, not in the full RISC-V pipeline. In the full system, the debug unit master (`du_master`) replaces this interface.
- `i_rx_done` and `i_tx_done` are registered into `rx_done_reg` / `tx_done_reg` to avoid glitch sensitivity on FIFO status signals.
