# Pipeline Latch Transmitter

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2026-05

## Description

Serializes the contents of the four pipeline registers (IF/ID, ID/EX, EX/MEM, MEM/WB) over UART as a fixed 45-byte little-endian packet. Triggered by a single `i_start` pulse; asserts `o_done` after the last byte is transmitted.

## Parameters

| Parameter      | Default | Description                          |
|----------------|:-------:|--------------------------------------|
| `NB_DATA`      | `32`    | Width of pipeline data fields.       |
| `NB_PC`        | `32`    | Width of the program counter.        |
| `NB_UART_DATA` | `8`     | Width of each UART byte.             |

## Ports

| Name               | Direction | Width          | Description                                        |
|--------------------|:---------:|:--------------:|----------------------------------------------------|
| `o_done`           | Output    | 1              | Asserted for one cycle after the last byte is sent.|
| `o_tx_start`       | Output    | 1              | UART transmitter start pulse.                      |
| `o_wr`             | Output    | 1              | UART FIFO write enable.                            |
| `o_wdata`          | Output    | `NB_UART_DATA` | Byte to write to the UART FIFO.                    |
| `i_start`          | Input     | 1              | Start transmission pulse.                          |
| `i_ifid_pc`        | Input     | `NB_PC`        | IF/ID pipeline register — PC value.                |
| `i_ifid_instr`     | Input     | `NB_DATA`      | IF/ID pipeline register — instruction word.        |
| `i_idex_ctrl`      | Input     | 9              | ID/EX pipeline register — control signals.         |
| `i_idex_rs1_data`  | Input     | `NB_DATA`      | ID/EX pipeline register — rs1 data.                |
| `i_idex_rs2_data`  | Input     | `NB_DATA`      | ID/EX pipeline register — rs2 data.                |
| `i_idex_imm`       | Input     | `NB_DATA`      | ID/EX pipeline register — immediate value.         |
| `i_idex_rd_addr`   | Input     | 5              | ID/EX pipeline register — destination address.     |
| `i_idex_rs1_addr`  | Input     | 5              | ID/EX pipeline register — rs1 address.             |
| `i_idex_rs2_addr`  | Input     | 5              | ID/EX pipeline register — rs2 address.             |
| `i_exmem_ctrl`     | Input     | 4              | EX/MEM pipeline register — control signals.        |
| `i_exmem_alu`      | Input     | `NB_DATA`      | EX/MEM pipeline register — ALU result.             |
| `i_exmem_data2`    | Input     | `NB_DATA`      | EX/MEM pipeline register — store data.             |
| `i_exmem_rd_addr`  | Input     | 5              | EX/MEM pipeline register — destination address.    |
| `i_memwb_ctrl`     | Input     | 2              | MEM/WB pipeline register — control signals.        |
| `i_memwb_data`     | Input     | `NB_DATA`      | MEM/WB pipeline register — memory read data.       |
| `i_memwb_alu`      | Input     | `NB_DATA`      | MEM/WB pipeline register — ALU result.             |
| `i_memwb_rd_addr`  | Input     | 5              | MEM/WB pipeline register — destination address.    |
| `i_tx_done`        | Input     | 1              | UART transmitter done acknowledgment.              |
| `i_rst`            | Input     | 1              | Synchronous active-high reset.                     |
| `clk`              | Input     | 1              | System clock.                                      |

## Packet Layout

All multi-byte fields are serialized little-endian (LSB first).

| Bytes     | Field              | Notes                                    |
|-----------|--------------------|------------------------------------------|
| `[0..3]`  | IF/ID PC           | 4 bytes, LE                              |
| `[4..7]`  | IF/ID Instruction  | 4 bytes, LE                              |
| `[8..9]`  | ID/EX Control      | 9-bit field; byte 9 = `{7'b0, ctrl[8]}` |
| `[10..13]`| ID/EX rs1 data     | 4 bytes, LE                              |
| `[14..17]`| ID/EX rs2 data     | 4 bytes, LE                              |
| `[18..21]`| ID/EX immediate    | 4 bytes, LE                              |
| `[22]`    | ID/EX rd address   | `{3'b0, rd[4:0]}`                        |
| `[23]`    | ID/EX rs1 address  | `{3'b0, rs1[4:0]}`                       |
| `[24]`    | ID/EX rs2 address  | `{3'b0, rs2[4:0]}`                       |
| `[25]`    | EX/MEM Control     | `{4'b0, ctrl[3:0]}`                      |
| `[26..29]`| EX/MEM ALU result  | 4 bytes, LE                              |
| `[30..33]`| EX/MEM store data  | 4 bytes, LE                              |
| `[34]`    | EX/MEM rd address  | `{3'b0, rd[4:0]}`                        |
| `[35]`    | MEM/WB Control     | `{6'b0, ctrl[1:0]}`                      |
| `[36..39]`| MEM/WB memory data | 4 bytes, LE                              |
| `[40..43]`| MEM/WB ALU result  | 4 bytes, LE                              |
| `[44]`    | MEM/WB rd address  | `{3'b0, rd[4:0]}`                        |

## State Machine

| State       | Description                                                          |
|-------------|----------------------------------------------------------------------|
| `IDLE`      | Waits for `i_start`. Resets byte counter to zero.                   |
| `SEND_BYTE` | Drives `o_wr`, `o_tx_start`, and `o_wdata` for the current byte.    |
| `WAIT_TXD`  | Waits for `i_tx_done`. Advances counter or returns to `IDLE`.       |

## Behavior

- **Type:** Registered FSM with combinational output logic; clock-synchronous reset.
- **Transmission:** One byte per `SEND_BYTE → WAIT_TXD` cycle. Total 45 cycles for a full dump.
- **Done pulse:** `o_done` is asserted for exactly one cycle when `byte_cnt == 44` and `i_tx_done` is received.

## Design Notes

- The 45-byte packet is assembled as a single combinational `wire [359:0] pkt_data` using `assign` slices, keeping the datapath purely combinational and synthesis-friendly.
- The 9-bit ID/EX control word is split across two bytes; the upper bit is zero-padded to a full byte.
