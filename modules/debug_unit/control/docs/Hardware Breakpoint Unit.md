# Hardware Breakpoint Unit

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-02

## Description

Maintains a bank of `N_BKP` hardware breakpoint slots, each with a 32-bit address and a valid bit. Continuously compares the current PC against all active slots and asserts `o_bkp_hit` whenever any match is detected. Breakpoints are added via a set pulse and removed by address via a clear pulse.

## Parameters

| Parameter | Default | Description                             |
|-----------|:-------:|-----------------------------------------|
| `NB_DATA` | `32`    | Width of the PC and breakpoint address. |
| `N_BKP`   | `4`     | Number of breakpoint slots.             |

## Ports

| Name         | Direction | Width     | Description                                          |
|--------------|:---------:|:---------:|------------------------------------------------------|
| `o_bkp_hit`  | Output    | 1         | High when the current PC matches any active slot.    |
| `i_pc`       | Input     | `NB_DATA` | Current program counter value.                       |
| `i_set`      | Input     | 1         | Pulse to store `i_bkp_addr` in the next free slot.  |
| `i_clr`      | Input     | 1         | Pulse to invalidate all slots matching `i_bkp_addr`.|
| `i_bkp_addr` | Input     | `NB_DATA` | Address to set or clear.                             |
| `i_rst`      | Input     | 1         | Synchronous active-high reset.                       |
| `clk`        | Input     | 1         | System clock.                                        |

## Behavior

- **Hit detection:** Purely combinational — each slot independently asserts a bit in `hit_vec` when its valid bit is set and its stored address matches `i_pc`. `o_bkp_hit` is the OR-reduction of all bits in `hit_vec`.
- **Set:** On `i_set`, a combinational priority scan finds the lowest-indexed invalid slot (`free_slot`). On the next rising edge the address is written and the valid bit is asserted. If all slots are occupied, the set pulse is silently ignored.
- **Clear:** On `i_clr`, all slots whose stored address matches `i_bkp_addr` have their valid bits deasserted synchronously.
- **Reset:** Clears all valid bits and zeros all stored addresses.

## Design Notes

- The `free_slot` scan uses a `for` loop with a `free_found` flag to ensure only the first available slot is selected, preventing double-allocation.
- Slot addresses are not cleared on invalidation; only the valid bit is reset. This simplifies logic without affecting correctness.
- `o_bkp_hit` has zero latency from a PC change — useful for cycle-accurate single-step halt detection.
