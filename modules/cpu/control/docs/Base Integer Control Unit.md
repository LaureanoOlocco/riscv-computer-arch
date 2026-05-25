# Base Integer Control Unit

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-02

## Description

Generates the pipeline control signals for the main RISC-V instruction types (R, I, S, B, U, J) based on the `opcode` and `func3` fields of the current instruction. The output is a packed control word that drives the datapath muxes, memory enables, register write, and ALU operation selectors.

## Parameters

| Parameter   | Default | Description                                  |
|-------------|:-------:|----------------------------------------------|
| `NB_CTRL`   | `9`     | Total number of control signal bits.         |
| `NB_OPCODE` | `7`     | Width of the instruction opcode field.       |
| `NB_FUNC3`  | `3`     | Width of the instruction `func3` field.      |

## Ports

| Name       | Direction | Width     | Description                              |
|------------|:---------:|:---------:|------------------------------------------|
| `o_ctrl`   | Output    | `NB_CTRL` | Packed control word for the datapath.    |
| `i_opcode` | Input     | `NB_OPCODE`| Opcode field of the current instruction.|
| `i_func3`  | Input     | `NB_FUNC3` | `func3` field of the current instruction.|

## Control Word Bit Mapping

| Bit index          | Signal name   | Description                                  |
|--------------------|---------------|----------------------------------------------|
| `[0]`              | `RegWrite`    | Enable write to the register file.           |
| `[1]`              | `MemRead`     | Enable memory read (load instructions).      |
| `[2]`              | `MemWrite`    | Enable memory write (store instructions).    |
| `[3]`              | `ALUSrc`      | Select immediate as ALU second operand.      |
| `[4]`              | `MemToReg`    | Route memory data to write-back.             |
| `[5:6]`            | `ALUOp`       | High-level ALU operation class.              |
| `[7:8]`            | `DataSize`    | Memory access granularity (byte/half/word).  |

## Data Size Encoding (`DataSize`)

| `func3`  | Encoding | Access size  |
|----------|:--------:|--------------|
| `3'b000` | `2'b01`  | Byte         |
| `3'b001` | `2'b10`  | Half-word    |
| `3'b010` | `2'b11`  | Word         |
| `3'b100` | `2'b01`  | Byte (LBU)   |
| `3'b101` | `2'b10`  | Half (LHU)   |
| default  | `2'b00`  | None         |

## Control Signals by Instruction Type

| Opcode       | Type    | RegWrite | MemRead | MemWrite | ALUSrc | MemToReg | ALUOp  |
|--------------|---------|:--------:|:-------:|:--------:|:------:|:--------:|:------:|
| `7'b0110011` | R-Type  | 1        | 0       | 0        | 0      | 0        | `2'b11`|
| `7'b0010011` | I-Type  | 1        | 0       | 0        | 1      | 0        | `2'b10`|
| `7'b0000011` | Load    | 1        | 1       | 0        | 1      | 1        | `2'b00`|
| `7'b0100011` | Store   | 0        | 0       | 1        | 1      | 0        | `2'b00`|
| `7'b0110111` | U-Type  | 1        | 0       | 0        | 1      | 0        | `2'b00`|
| default      | —       | 0        | 0       | 0        | 0      | 0        | `2'b00`|

## Behavior

- **Type:** Purely combinational (`always @(*)`).
- **Default:** All control signals are cleared to prevent latches on unrecognized opcodes.
- **Latency:** 0.