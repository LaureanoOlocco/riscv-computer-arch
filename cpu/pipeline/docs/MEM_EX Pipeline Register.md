# EX/MEM Pipeline Register

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-01-25

## Description

Latches the ALU result, the second register operand (for store data), the destination register address, the data-size and function code, and the memory/write-back control signals at the end of the Execute stage. Supports flush and enable.

## Parameters

| Parameter      | Default | Description                       |
|----------------|:-------:|-----------------------------------|
| `NB_PC`        | `32`    | PC width.                         |
| `NB_DATA`      | `32`    | Data bus width.                   |
| `NB_ADDR`      | `5`     | Register address width.           |
| `NB_FUNC3`     | `3`     | `func3` field width.              |
| `NB_DATA_SIZE` | `2`     | Data-size control field width.    |

## Ports

| Name           | Dir    | Width          | Description                          |
|----------------|--------|:--------------:|--------------------------------------|
| `o_reg_write`  | Output | 1              | Register file write enable.          |
| `o_mem_read`   | Output | 1              | Memory read enable.                  |
| `o_mem_write`  | Output | 1              | Memory write enable.                 |
| `o_mem_to_reg` | Output | 1              | Write-back source selector.          |
| `o_data_size`  | Output | `NB_DATA_SIZE` | Memory access granularity.           |
| `o_alu`        | Output | `NB_DATA`      | ALU result.                          |
| `o_data2`      | Output | `NB_DATA`      | rs2 data (store data).               |
| `o_rd_addr`    | Output | `NB_ADDR`      | Destination register address.        |
| `o_func3`      | Output | `NB_FUNC3`     | `func3` field.                       |
| `i_flush`      | Input  | 1              | Clears all registers (NOP bubble).   |
| `i_enable`     | Input  | 1              | Write enable.                        |
| `clock`        | Input  | 1              | System clock.                        |

## Behavior

On `posedge clock`: if `i_flush`, all registers are cleared. Otherwise, if `i_enable`, all fields are latched.