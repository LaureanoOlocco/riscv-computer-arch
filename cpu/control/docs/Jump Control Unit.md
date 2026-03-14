# Jump Control Unit

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2026-01-15

## Description

Generates control signals for jump instructions (`JAL` and `JALR`) decoded in the ID stage. Determines the next PC source, whether the return address should be written back to the register file, and whether the pipeline must be flushed. All outputs are suppressed when the pipeline is stalled.

## Parameters

| Parameter    | Default | Description                           |
|--------------|:-------:|---------------------------------------|
| `NB_PC`      | `32`    | Width of the program counter.         |
| `NB_OPCODE`  | `7`     | Width of the instruction opcode.      |
| `NB_PC_SRC`  | `2`     | Width of the PC source selector.      |

## Ports

| Name           | Direction | Width       | Description                                               |
|----------------|:---------:|:-----------:|-----------------------------------------------------------|
| `o_pc_src`     | Output    | `NB_PC_SRC` | Selects the next PC source.                               |
| `o_reg_write`  | Output    | 1           | Asserted when the return address must be saved to `rd`.   |
| `o_flush`      | Output    | 1           | Asserted to flush the IF stage after a taken jump.        |
| `i_opcode`     | Input     | `NB_OPCODE` | Opcode of the instruction in the ID stage.                |
| `i_stall`      | Input     | 1           | When high, all outputs are held at their default values.  |

## PC Source Encoding

| `o_pc_src` | Next PC source                        |
|:----------:|---------------------------------------|
| `2'b00`    | Normal — PC + 4.                      |
| `2'b01`    | JAL target — PC + immediate offset.   |
| `2'b10`    | JALR target — rs1 + immediate offset. |

## Behavior per Opcode

| Opcode       | Instruction | `o_pc_src` | `o_reg_write` | `o_flush` |
|--------------|-------------|:----------:|:-------------:|:---------:|
| `7'b1101111` | JAL         | `2'b01`    | 1             | 1         |
| `7'b1100111` | JALR        | `2'b10`    | 1             | 1         |
| others       | —           | `2'b00`    | 0             | 0         |

All outputs default to zero when `i_stall` is asserted.

## Behavior

- **Type:** Purely combinational (`always @(*)`).
- **Latency:** 0.