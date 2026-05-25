# ID/EX Pipeline Register

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-01-25

## Description

Latches control signals, register read data, the sign-extended immediate, and instruction fields at the end of the Instruction Decode stage for use by the Execute stage. Unpacks the control word from the main Control Unit into individual signals. Supports flush and enable.

## Parameters

| Parameter      | Default             | Description                              |
|----------------|:-------------------:|------------------------------------------|
| `NB_DATA`      | `32`                | Data bus width.                          |
| `NB_CTRL`      | `9`                 | Control word width.                      |
| `NB_INSTR`     | `32`                | Instruction width.                       |
| `NB_PC`        | `32`                | Program counter width.                   |
| `NB_OP_CODE`   | `6`                 | ALU opcode width.                        |
| `NB_ADDR`      | `$clog2(NB_INSTR)`  | Register address width.                  |
| `NB_FUNC3`     | `3`                 | `func3` field width.                     |
| `NB_FUNC7`     | `7`                 | `func7` field width.                     |
| `NB_ALU_OP`    | `2`                 | ALUOp selector width.                    |
| `NB_DATA_SIZE` | `6`                 | Data-size control field width.           |

## Ports — Outputs

| Name           | Width        | Description                              |
|----------------|:------------:|------------------------------------------|
| `o_reg_write`  | 1            | Register file write enable.              |
| `o_mem_read`   | 1            | Memory read enable.                      |
| `o_mem_write`  | 1            | Memory write enable.                     |
| `o_alu_source` | 1            | ALU B-operand selector (reg vs imm).     |
| `o_mem_to_reg` | 1            | Write-back source selector.              |
| `o_alu_op`     | `NB_ALU_OP`  | ALUOp for the ALU Control Unit.          |
| `o_data_size`  | `NB_DATA_SIZE`| Memory access granularity.              |
| `o_rs1_data`   | `NB_DATA`    | Read data from rs1.                      |
| `o_rs2_data`   | `NB_DATA`    | Read data from rs2.                      |
| `o_immediate`  | `NB_DATA`    | Sign-extended immediate.                 |
| `o_rd_addr`    | `NB_ADDR`    | Destination register address.            |
| `o_func3`      | `NB_FUNC3`   | `func3` field.                           |
| `o_rs1_addr`   | `NB_ADDR`    | Source register 1 address.               |
| `o_rs2_addr`   | `NB_ADDR`    | Source register 2 address.               |
| `o_func7`      | `NB_FUNC7`   | `func7` field.                           |

## Ports — Inputs

| Name        | Width     | Description                              |
|-------------|:---------:|------------------------------------------|
| `i_control` | `NB_CTRL` | Packed control word from the CU.         |
| `i_flush`   | 1         | Clears all registers (NOP bubble).       |
| `i_enable`  | 1         | Write enable — deasserted to stall.      |
| `clock`     | 1         | System clock.                            |

(Data inputs mirror the output names with the `i_` prefix.)

## Behavior

On `posedge clock`: if `i_flush`, all registers are cleared. Otherwise, if `i_enable`, control bits are unpacked from `i_control` using local parameter indices, and all data fields are latched.