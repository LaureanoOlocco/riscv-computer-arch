# Program Counter

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-12-08

## Description

Holds the current value of the Program Counter and updates it synchronously on the rising clock edge. Write enable support allows the PC to be frozen during pipeline stalls. Synchronous reset clears the PC to zero.

## Parameters

| Parameter | Default | Description              |
|-----------|:-------:|--------------------------|
| `NB_PC`   | `32`    | Width of the PC register.|

## Ports

| Name        | Direction | Width   | Description                                         |
|-------------|:---------:|:-------:|-----------------------------------------------------|
| `o_pc`      | Output    | `NB_PC` | Current PC value.                                   |
| `i_pc`      | Input     | `NB_PC` | Next PC value to load.                              |
| `i_write_en`| Input     | 1       | When high, the PC is updated on the next clock edge.|
| `i_reset`   | Input     | 1       | Synchronous reset — clears PC to zero.              |
| `clock`     | Input     | 1       | System clock.                                       |

## Behavior

On `posedge clock`: if `i_reset`, PC ← 0. Otherwise, if `i_write_en`, PC ← `i_pc`. Deasserting `i_write_en` freezes the PC, enabling pipeline stall support.
