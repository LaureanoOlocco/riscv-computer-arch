# EX Stage Forwarding Unit

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2026-01-15

## Description

Resolves data hazards for the instruction currently in the EX stage by detecting when a result from the MEM or WB stage can be forwarded directly to one of its ALU inputs. Checks both source registers (`rs1` and `rs2`) independently. MEM-stage forwarding is given priority over WB-stage forwarding when both would apply.

## Parameters

| Parameter    | Default | Description                         |
|--------------|:-------:|-------------------------------------|
| `NB_ADDR`    | `5`     | Width of the register address bus.  |
| `NB_FORWARD` | `2`     | Width of the forwarding select bus. |

## Ports

| Name             | Direction | Width        | Description                                            |
|------------------|:---------:|:------------:|--------------------------------------------------------|
| `o_forward_a`    | Output    | `NB_FORWARD` | Forwarding selector for ALU operand A (rs1).           |
| `o_forward_b`    | Output    | `NB_FORWARD` | Forwarding selector for ALU operand B (rs2).           |
| `i_ex_rs1`       | Input     | `NB_ADDR`    | Source register 1 of the EX-stage instruction.         |
| `i_ex_rs2`       | Input     | `NB_ADDR`    | Source register 2 of the EX-stage instruction.         |
| `i_mem_rd`       | Input     | `NB_ADDR`    | Destination register of the MEM-stage instruction.     |
| `i_wb_rd`        | Input     | `NB_ADDR`    | Destination register of the WB-stage instruction.      |
| `i_mem_reg_write`| Input     | 1            | MEM-stage instruction writes to the register file.     |
| `i_wb_reg_write` | Input     | 1            | WB-stage instruction writes to the register file.      |

## Forwarding Encoding

| `o_forward_x` | Source         |
|:-------------:|----------------|
| `2'b00`       | No forwarding — use register file value. |
| `2'b01`       | Forward from MEM stage.                  |
| `2'b10`       | Forward from WB stage.                   |

## Forwarding Conditions

For each operand `x` ∈ {rs1, rs2}:

- **MEM → EX:** `i_mem_reg_write && (i_mem_rd != 0) && (i_mem_rd == i_ex_rx)` → `2'b01`
- **WB → EX:** `i_wb_reg_write && (i_wb_rd != 0) && no MEM hazard && (i_wb_rd == i_ex_rx)` → `2'b10`

MEM forwarding has priority — the WB path is only taken when MEM does not also match.

## Behavior

- **Type:** Purely combinational (`always @(*)`).
- **Latency:** 0.