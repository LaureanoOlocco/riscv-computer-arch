# IF/ID Pipeline Register

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-01-25

## Description

Captures the instruction word, current PC, and next PC at the end of the Instruction Fetch stage and holds them stable for the Instruction Decode stage. Also pre-decodes instruction fields (opcode, rd, rs1, rs2, func3, func7) to reduce combinational depth in the ID stage. Supports synchronous reset and flush.

## Parameters

| Parameter    | Default          | Description                                |
|--------------|:----------------:|--------------------------------------------|
| `NB_INSTR`   | `32`             | Instruction width.                         |
| `NB_PC`      | `32`             | Program counter width.                     |
| `NB_OP_CODE` | `6`              | Opcode field width.                        |
| `NB_ADDR`    | `$clog2(NB_INSTR)`| Register address width.                   |
| `NB_FUNC3`   | `3`              | `func3` field width.                       |
| `NB_FUNC7`   | `7`              | `func7` field width.                       |

## Ports

| Name            | Direction | Width        | Description                                    |
|-----------------|:---------:|:------------:|------------------------------------------------|
| `o_pc`          | Output    | `NB_PC`      | Registered current PC.                         |
| `o_pc_next`     | Output    | `NB_PC`      | Registered PC + 4.                             |
| `o_instruction` | Output    | `NB_INSTR`   | Registered full instruction word.              |
| `o_opcode`      | Output    | `NB_OP_CODE` | Opcode field `[6:0]`.                          |
| `o_rd_addr`     | Output    | `NB_ADDR`    | Destination register `[11:7]`.                 |
| `o_func3`       | Output    | `NB_FUNC3`   | Function code `[14:12]`.                       |
| `o_rs1_addr`    | Output    | `NB_ADDR`    | Source register 1 `[19:15]`.                   |
| `o_rs2_addr`    | Output    | `NB_ADDR`    | Source register 2 `[24:20]`.                   |
| `o_func7`       | Output    | `NB_FUNC7`   | Function code `[31:25]`.                       |
| `i_instruction` | Input     | `NB_INSTR`   | Instruction from memory.                       |
| `i_pc`          | Input     | `NB_PC`      | Current PC.                                    |
| `i_pc_next`     | Input     | `NB_PC`      | PC + 4.                                        |
| `i_flush`       | Input     | 1            | Clears all registers (inserts NOP bubble).     |
| `i_enable`      | Input     | 1            | Write enable — deasserted to stall the stage.  |
| `i_rst`         | Input     | 1            | Synchronous reset — clears all registers.      |
| `clock`         | Input     | 1            | System clock.                                  |

## Behavior

On `posedge clock`: if `i_rst || i_flush`, all outputs are cleared to zero. Otherwise, if `i_enable`, all fields are latched from their inputs.