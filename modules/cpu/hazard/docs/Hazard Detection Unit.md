# Hazard Detection Unit

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2026-01-15

## Description

Detects load-use data hazards in the pipeline. A hazard occurs when the instruction in the EX stage is a load and its destination register matches either source register of the instruction currently in the ID stage. When detected, the unit stalls the pipeline for one cycle by deasserting the write enable and asserting the control mux signal to insert a bubble.

## Parameters

| Parameter | Default | Description                        |
|-----------|:-------:|------------------------------------|
| `NB_ADDR` | `5`     | Width of the register address bus. |

## Ports

| Name               | Direction | Width     | Description                                                   |
|--------------------|:---------:|:---------:|---------------------------------------------------------------|
| `o_write_enable`   | Output    | 1         | Low when a hazard is detected — stalls IF/ID and PC.          |
| `o_control_mux`    | Output    | 1         | High when a hazard is detected — selects NOP bubble in ID/EX. |
| `i_id_ex_mem_read` | Input     | 1         | Indicates the EX-stage instruction is a load.                 |
| `i_id_ex_rd`       | Input     | `NB_ADDR` | Destination register of the EX-stage instruction.             |
| `i_if_id_rs1`      | Input     | `NB_ADDR` | First source register of the ID-stage instruction.            |
| `i_if_id_rs2`      | Input     | `NB_ADDR` | Second source register of the ID-stage instruction.           |

## Hazard Condition

A stall is inserted when all three conditions hold simultaneously:

```
i_id_ex_mem_read == 1
AND
(i_id_ex_rd == i_if_id_rs1  OR  i_id_ex_rd == i_if_id_rs2)
```

## Behavior

- **Type:** Purely combinational (`always @(*)`).
- **Default (no hazard):** `o_write_enable = 1`, `o_control_mux = 0` — pipeline advances normally.
- **Stall (hazard):** `o_write_enable = 0`, `o_control_mux = 1` — PC and IF/ID register are frozen; a NOP bubble is injected into ID/EX.
- **Latency:** 0.