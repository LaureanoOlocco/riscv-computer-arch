# Arithmetic Logic Unit

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-10-09

## Description

Synthesizable, parameterizable ALU intended for FPGA targets. Implements a purely combinational arithmetic and logic core — no clock or reset in the datapath. The data width and opcode width are both configurable via parameters, enabling reuse across designs of different sizes.


## Parameters

| Parameter    | Default | Description                        |
|--------------|---------|------------------------------------|
| `NB_DATA`    | `32`    | Width of input operands and result. |
| `NB_OP_CODE` | `6`     | Width of the operation selector.    |


## Ports

| Name        | Direction | Width        | Description                             |
|-------------|:---------:|:------------:|-----------------------------------------|
| `o_result`  | Output    | `NB_DATA`    | Result of the selected ALU operation.   |
| `o_zero`    | Output    | 1            | High when `o_result == 0`.              |
| `o_carry`   | Output    | 1            | Carry-out flag for ADD/SUB operations.  |
| `i_data_a`  | Input     | `NB_DATA`    | First operand.                          |
| `i_data_b`  | Input     | `NB_DATA`    | Second operand.                         |
| `i_op_code` | Input     | `NB_OP_CODE` | Selects the operation to perform.       |


## Operation Codes

| `i_op_code` | Operation | Description                              |
|-------------|-----------|------------------------------------------|
| `6'b100000` | ADD       | Unsigned addition with carry tracking.  |
| `6'b100010` | SUB       | Unsigned subtraction with borrow track. |
| `6'b100100` | AND       | Bitwise AND.                             |
| `6'b100101` | OR        | Bitwise OR.                              |
| `6'b100110` | XOR       | Bitwise XOR.                             |
| `6'b000011` | SRA       | Arithmetic right shift (signed).         |
| `6'b000010` | SRL       | Logical right shift.                     |
| `6'b100111` | NOR       | Bitwise NOR.                             |
| others      | —         | Result forced to zero.                   |

## Flags

- **`o_zero`** — asserted when all bits of `o_result` are zero (`~|result`).
- **`o_carry`** — asserted when ADD overflows (carry-out = 1) or SUB does not borrow (borrow = 0). Computed from the internal `NB_DATA+1` bit result register.


## Behavior

- **Type:** Purely combinational — no registers or clock in the arithmetic path.
- **Shift amount:** For SRA and SRL, only the lower `⌈log₂(NB_DATA)⌉` bits of `i_data_b` are used as the shift amount.
- **Latency:** 0 — result propagates immediately with input changes.


## Design Notes

- An internal `NB_DATA+1` bit register `result` carries the extra bit needed to compute carry/borrow without additional logic.
- SRA uses `$signed()` cast to ensure arithmetic (sign-extending) shift behavior.
- The `default` case sets the result to all zeros, preventing latches during synthesis.