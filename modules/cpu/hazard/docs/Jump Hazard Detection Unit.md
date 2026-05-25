# Jump Hazard Detection Unit

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2026-01-15

## Description

Detects control hazards caused by data dependencies on jump and branch instructions resolved in the ID stage. If the instruction in EX is writing to a register that is needed by a `JALR` or branch instruction in ID, the pipeline must stall for one cycle. A sequential element tracks whether a stall was just issued to avoid double-stalling.

## Parameters

| Parameter   | Default | Description                        |
|-------------|:-------:|------------------------------------|
| `NB_OPCODE` | `7`     | Width of the instruction opcode.   |
| `NB_ADDR`   | `5`     | Width of the register address bus. |

## Ports

| Name             | Direction | Width       | Description                                               |
|------------------|:---------:|:-----------:|-----------------------------------------------------------|
| `o_write_enable` | Output    | 1           | Low when a hazard stall must be inserted.                 |
| `i_opcode`       | Input     | `NB_OPCODE` | Opcode of the instruction in the ID stage.                |
| `i_ex_reg_write` | Input     | 1           | EX-stage instruction writes to the register file.         |
| `i_ex_rd`        | Input     | `NB_ADDR`   | Destination register of the EX-stage instruction.         |
| `i_id_rs1`       | Input     | `NB_ADDR`   | Source register 1 of the ID-stage instruction.            |
| `i_id_rs2`       | Input     | `NB_ADDR`   | Source register 2 of the ID-stage instruction.            |
| `clock`          | Input     | 1           | System clock — used to track the previous stall state.    |

## Hazard Conditions

**JALR (`I_TYPE_3`):** stall if `i_ex_reg_write && (i_ex_rd == i_id_rs1) && not_stall`

**Branch (`B_TYPE`):** stall if `i_ex_reg_write && ((i_ex_rd == i_id_rs1) || (i_ex_rd == i_id_rs2)) && not_stall`

`not_stall` is a registered flag that prevents a second consecutive stall from being issued for the same hazard.

## Behavior

- **Combinational logic:** evaluates the stall condition each cycle.
- **Sequential logic:** `not_stall` is updated on `posedge clock` to reflect whether the previous cycle was a stall.
- **Default (no hazard):** `o_write_enable = 1` — pipeline advances normally.
- **Stall:** `o_write_enable = 0` — IF/ID register and PC are frozen.