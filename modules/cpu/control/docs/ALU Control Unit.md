# ALU Control Unit

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-12-20

## Description

Decodes the `ALUOp` signal from the main Control Unit together with the `funct3` and `funct7` fields of the current instruction to produce a 6-bit ALU operation code. Supports R-type and I-type arithmetic/logic instructions as well as load/store and branch operations.

## Parameters

| Parameter    | Default | Description                              |
|--------------|:-------:|------------------------------------------|
| `NB_ALU_OP`  | `2`     | Width of the `ALUOp` input from the CU.  |
| `NB_OP_CODE` | `6`     | Width of the ALU operation code output.  |
| `NB_FUNCT7`  | `7`     | Width of the `funct7` instruction field. |
| `NB_FUNCT3`  | `3`     | Width of the `funct3` instruction field. |

## Ports

| Name           | Direction | Width        | Description                                        |
|----------------|:---------:|:------------:|----------------------------------------------------|
| `o_alu_op_code`| Output    | `NB_OP_CODE` | 6-bit operation code sent to the ALU.              |
| `i_alu_op`     | Input     | `NB_ALU_OP`  | High-level operation class from the Control Unit.  |
| `i_funct7`     | Input     | `NB_FUNCT7`  | `funct7` field of the instruction word.            |
| `i_funct3`     | Input     | `NB_FUNCT3`  | `funct3` field of the instruction word.            |

## ALUOp Encoding

| `i_alu_op` | Instruction class | Resolved operation          |
|------------|-------------------|-----------------------------|
| `2'b00`    | Load / Store      | Always ADD (address calc).  |
| `2'b01`    | Branch (BEQ)      | Always SUB (comparison).    |
| `2'b10`    | R-Type            | Decoded from funct3/funct7. |
| `2'b11`    | I-Type            | Decoded from funct3/funct7. |

## Operation Code Table

| Class  | `funct3` | `funct7`    | Operation |
|--------|----------|-------------|-----------|
| R-Type | `3'b000` | `7'b0000000`| ADD       |
| R-Type | `3'b000` | `7'b0100000`| SUB       |
| R-Type | `3'b001` | —           | SLL       |
| R-Type | `3'b010` | —           | SLT       |
| R-Type | `3'b011` | —           | SLTU      |
| R-Type | `3'b100` | —           | XOR       |
| R-Type | `3'b101` | `7'b0000000`| SRL       |
| R-Type | `3'b101` | `7'b0100000`| SRA       |
| R-Type | `3'b110` | —           | OR        |
| R-Type | `3'b111` | —           | AND       |
| I-Type | `3'b000` | —           | ADDI      |
| I-Type | `3'b010` | —           | SLTI      |
| I-Type | `3'b011` | —           | SLTIU     |
| I-Type | `3'b100` | —           | XORI      |
| I-Type | `3'b110` | —           | ORI       |
| I-Type | `3'b111` | —           | ANDI      |
| I-Type | `3'b001` | —           | SLLI      |
| I-Type | `3'b101` | `7'b0000000`| SRLI      |
| I-Type | `3'b101` | `7'b0100000`| SRAI      |

## Behavior

- **Type:** Purely combinational (`always @(*)`).
- **Default:** ADD is the fallback operation to prevent latches.
- **Latency:** 0.