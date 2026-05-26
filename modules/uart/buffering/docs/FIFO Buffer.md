# FIFO Buffer

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-12

## Description

Parameterizable synchronous FIFO with separate read and write enables, full and empty status flags, and a registered data output. Depth is a power of two determined by `NB_ADDRESS`. Used as the RX and TX buffers in the UART subsystem.

## Parameters

| Parameter    | Default | Description                                          |
|--------------|:-------:|------------------------------------------------------|
| `NB_DATA`    | `8`     | Width of each data word.                             |
| `NB_ADDRESS` | `4`     | Address width. Buffer depth = `2^NB_ADDRESS` words.  |

## Ports

| Name          | Direction | Width     | Description                                       |
|---------------|:---------:|:---------:|---------------------------------------------------|
| `o_data`      | Output    | `NB_DATA` | Registered data at the current read pointer.      |
| `o_empty_flag`| Output    | 1         | High when the FIFO contains no valid entries.     |
| `o_full_flag` | Output    | 1         | High when the FIFO has no available write slots.  |
| `i_rd`        | Input     | 1         | Read enable — advances the read pointer.          |
| `i_wr`        | Input     | 1         | Write enable — stores `i_data` and advances the write pointer. |
| `i_data`      | Input     | `NB_DATA` | Data to write.                                    |
| `i_rst`       | Input     | 1         | Asynchronous active-high reset.                   |
| `clock`       | Input     | 1         | System clock.                                     |

## Behavior

- **Write:** When `i_wr` is asserted and `o_full_flag` is low, `i_data` is stored at the current write pointer and the write pointer is incremented.
- **Read:** When `i_rd` is asserted and `o_empty_flag` is low, `o_data` is updated to the word at the current read pointer on the next rising clock edge, and the read pointer is incremented.
- **Simultaneous read/write:** When both `i_wr` and `i_rd` are asserted and the buffer is not empty, both pointers advance together; the full and empty flags remain unchanged.
- **Reset:** Asynchronous — pointers and flags are cleared immediately on `i_rst` assertion. `o_data` is also cleared to zero.

## Status Flag Logic

| Condition                            | `o_full_flag` | `o_empty_flag` |
|--------------------------------------|:-------------:|:--------------:|
| Write pointer catches read pointer   | `1`           | —              |
| Read pointer catches write pointer   | —             | `1`            |
| Write-only (not full)                | updated       | `0`            |
| Read-only (not empty)                | `0`           | updated        |
| Both (not empty)                     | unchanged     | unchanged      |

## Design Notes

- Pointer arithmetic uses explicit zero-extension (`{{(NB_ADDRESS-1){1'b0}}, 1'b1}`) to avoid implicit width warnings during synthesis.
- `o_data` is a registered output driven by a dedicated `always @(posedge clock)` block, adding one cycle of read latency but improving timing closure.
- The `wr_en` wire is present in the port list but the write path is controlled directly by the `{i_wr, i_rd}` case statement, keeping the logic compact.
