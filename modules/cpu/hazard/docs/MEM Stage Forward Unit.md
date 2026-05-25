# MEM Stage Forwarding Unit

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2026-01-15

## Description

Handles the specific case where a store instruction in the MEM stage needs to write data that was produced by the instruction currently completing in the WB stage. Checks only `rs2` (the data operand of the store), as `rs1` (the address base) is covered by the EX forwarding unit.

## Parameters

| Parameter    | Default | Description                         |
|--------------|:-------:|-------------------------------------|
| `NB_ADDR`    | `5`     | Width of the register address bus.  |
| `NB_FORWARD` | `2`     | Width of the forwarding select bus. |

## Ports

| Name             | Direction | Width        | Description                                         |
|------------------|:---------:|:------------:|-----------------------------------------------------|
| `o_forward_b`    | Output    | `NB_FORWARD` | Forwarding selector for the store data operand.     |
| `i_mem_rs2`      | Input     | `NB_ADDR`    | Source register 2 of the MEM-stage instruction.     |
| `i_wb_rd`        | Input     | `NB_ADDR`    | Destination register of the WB-stage instruction.   |
| `i_wb_reg_write` | Input     | 1            | WB-stage instruction writes to the register file.   |

## Forwarding Encoding

| `o_forward_b` | Source                                        |
|:-------------:|-----------------------------------------------|
| `2'b00`       | No forwarding — use data from MEM-stage reg.  |
| `2'b01`       | Forward from WB stage.                        |

## Forwarding Condition

`i_wb_reg_write && (i_wb_rd != 0) && (i_wb_rd == i_mem_rs2)` → `2'b01`

## Behavior

- **Type:** Purely combinational (`always @(*)`).
- **Latency:** 0.