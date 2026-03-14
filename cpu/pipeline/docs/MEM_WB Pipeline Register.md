#  MEM/WB Pipeline Register

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-01-25

## Description

Latches the memory read data, the ALU result, the destination register address, the `func3` field, and the write-back control signals at the end of the Memory Access stage. Provides all signals needed by the Write Back stage to complete an instruction. Supports enable only (no flush).

## Parameters

| Parameter  | Default | Description              |
|------------|:-------:|--------------------------|
| `NB_PC`    | `32`    | PC width.                |
| `NB_DATA`  | `32`    | Data bus width.          |
| `NB_ADDR`  | `5`     | Register address width.  |
| `NB_FUNC3` | `3`     | `func3` field width.     |

## Ports

| Name           | Dir    | Width     | Description                              |
|----------------|--------|:---------:|------------------------------------------|
| `o_reg_write`  | Output | 1         | Register file write enable.              |
| `o_mem_to_reg` | Output | 1         | Selects memory data or ALU result for WB.|
| `o_data`       | Output | `NB_DATA` | Data read from memory.                   |
| `o_alu`        | Output | `NB_DATA` | ALU result passed through.               |
| `o_rd_addr`    | Output | `NB_ADDR` | Destination register address.            |
| `o_func3`      | Output | `NB_FUNC3`| `func3` field (for load sign extension). |
| `i_enable`     | Input  | 1         | Write enable — deasserted to stall.      |
| `clock`        | Input  | 1         | System clock.                            |

## Behavior

On `posedge clock`: if `i_enable`, all fields are latched from inputs. No flush input — this stage is never flushed since instructions that reach MEM have already been committed to execution.