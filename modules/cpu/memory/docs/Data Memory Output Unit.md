# Data Memory Output Unit

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2026-01-15

## Description

Post-processes raw data read from memory before it reaches the Write Back stage. Performs sign extension or zero extension based on the `func3` field of the load instruction, producing the correctly sized value for the destination register.

## Parameters

| Parameter  | Default | Description               |
|------------|:-------:|---------------------------|
| `NB_DATA`  | `32`    | Width of the data bus.    |
| `NB_FUNC3` | `3`     | Width of the func3 field. |

## Ports

| Name      | Direction | Width     | Description                                    |
|-----------|:---------:|:---------:|------------------------------------------------|
| `o_data`  | Output    | `NB_DATA` | Sign/zero-extended output word.                |
| `i_data`  | Input     | `NB_DATA` | Raw word read from data memory.                |
| `i_func3` | Input     | `NB_FUNC3`| Load instruction func3 — selects extension.   |

## Extension Encoding

| `i_func3` | Instruction | Operation                                         |
|:---------:|-------------|---------------------------------------------------|
| `3'b000`  | LB          | Sign-extend byte `[7:0]` to `NB_DATA` bits.       |
| `3'b001`  | LH          | Sign-extend halfword `[15:0]` to `NB_DATA` bits.  |
| `3'b010`  | LW          | Pass through full word unchanged.                 |
| `3'b100`  | LBU         | Zero-extend byte `[7:0]` to `NB_DATA` bits.       |
| `3'b101`  | LHU         | Zero-extend halfword `[15:0]` to `NB_DATA` bits.  |
| default   | —           | Pass through full word unchanged.                 |

## Behavior

- **Type:** Purely combinational (`always @(*)`).
- **Latency:** 0.