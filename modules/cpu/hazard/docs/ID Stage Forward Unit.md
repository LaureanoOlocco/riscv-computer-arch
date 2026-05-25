# ID Stage Forwarding Unit

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2026-01-15

## Description

Resolves data hazards for the instruction in the ID stage (used for branch and jump comparisons that are resolved early). Checks both source registers against the MEM and WB stages. MEM-stage forwarding is skipped for load instructions, as their result is not yet available at the end of the MEM stage.

## Parameters

| Parameter    | Default | Description                         |
|--------------|:-------:|-------------------------------------|
| `NB_ADDR`    | `5`     | Width of the register address bus.  |
| `NB_FORWARD` | `2`     | Width of the forwarding select bus. |

## Ports

| Name              | Direction | Width        | Description                                            |
|-------------------|:---------:|:------------:|--------------------------------------------------------|
| `o_forward_a`     | Output    | `NB_FORWARD` | Forwarding selector for ID operand A (rs1).            |
| `o_forward_b`     | Output    | `NB_FORWARD` | Forwarding selector for ID operand B (rs2).            |
| `i_id_rs1`        | Input     | `NB_ADDR`    | Source register 1 of the ID-stage instruction.         |
| `i_id_rs2`        | Input     | `NB_ADDR`    | Source register 2 of the ID-stage instruction.         |
| `i_mem_rd`        | Input     | `NB_ADDR`    | Destination register of the MEM-stage instruction.     |
| `i_wb_rd`         | Input     | `NB_ADDR`    | Destination register of the WB-stage instruction.      |
| `i_mem_reg_write` | Input     | 1            | MEM-stage instruction writes to the register file.     |
| `i_wb_reg_write`  | Input     | 1            | WB-stage instruction writes to the register file.      |
| `i_mem_mem_read`  | Input     | 1            | MEM-stage instruction is a load — blocks MEM forwarding.|

## Forwarding Encoding

| `o_forward_x` | Source                          |
|:-------------:|---------------------------------|
| `2'b00`       | No forwarding.                  |
| `2'b01`       | Forward from MEM stage.         |
| `2'b10`       | Forward from WB stage.          |

## Key Difference from EX Forwarding Unit

MEM → ID forwarding is only allowed when `i_mem_mem_read == 0`. If the MEM-stage instruction is a load, its result is unavailable and the hazard detection unit must insert a stall instead.

## Behavior

- **Type:** Purely combinational (`always @(*)`).
- **Latency:** 0.