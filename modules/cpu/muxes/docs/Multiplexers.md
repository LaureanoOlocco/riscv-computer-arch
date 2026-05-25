# Parameterizable Multiplexers

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-12-08 / 2025-12-13

## Description

A family of purely combinational, parameterizable multiplexers used throughout the RISC-V datapath. All three share the same interface style; they differ only in the number of input channels.

## Parameters

| Parameter   | Default | Applies to        | Description                        |
|-------------|:-------:|-------------------|------------------------------------|
| `NB_MUX`    | `32`    | all               | Data width of each input/output.   |
| `NB_SELECT` | `2`     | mux3to1, mux4to1  | Width of the select signal.        |

`mux2to1` uses a 1-bit select implicitly.

## Ports

| Name       | Direction | Width      | Description                              |
|------------|:---------:|:----------:|------------------------------------------|
| `o_mux`    | Output    | `NB_MUX`   | Selected input channel.                  |
| `i_data_a` | Input     | `NB_MUX`   | Channel A (`sel = 2'b00` / `1'b0`).      |
| `i_data_b` | Input     | `NB_MUX`   | Channel B (`sel = 2'b01` / `1'b1`).      |
| `i_data_c` | Input     | `NB_MUX`   | Channel C (`sel = 2'b10`). *(3:1, 4:1)*  |
| `i_data_d` | Input     | `NB_MUX`   | Channel D (`sel = 2'b11`). *(4:1 only)*  |
| `i_data_sel`| Input   | 1 / `NB_SELECT` | Channel selector.                  |

## Select Encoding

| `i_data_sel` | mux2to1 | mux3to1 | mux4to1 |
|:------------:|:-------:|:-------:|:-------:|
| `0` / `2'b00`| A       | A       | A       |
| `1` / `2'b01`| B       | B       | B       |
| `2'b10`      | —       | C       | C       |
| `2'b11`      | —       | —       | D       |

## Behavior

- **Type:** Purely combinational (`always @(*)`).
- **Default:** Output is cleared to zero on unmatched select values, preventing latches.
- **Latency:** 0.