# Block RAM

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-12-08

## Description

Parameterizable dual-read-port / single-write-port Block RAM, inferred as FPGA BRAM via the `ram_style = "block"` attribute. Write is synchronous on the rising clock edge; both read ports are synchronous on the falling clock edge. All memory locations are initialized to zero at simulation start.

## Parameters

| Parameter    | Default | Description                                          |
|--------------|:-------:|------------------------------------------------------|
| `NB_DATA`    | `32`    | Width of each memory word.                           |
| `NB_ADDRESS` | `8`     | Address width. Memory depth = `2^NB_ADDRESS` words.  |

## Ports

| Name               | Direction | Width        | Description                                      |
|--------------------|:---------:|:------------:|--------------------------------------------------|
| `o_data_a`         | Output    | `NB_DATA`    | Read data from port A.                           |
| `o_data_b`         | Output    | `NB_DATA`    | Read data from port B.                           |
| `i_read_en_data_a` | Input     | 1            | Enable read on port A.                           |
| `i_read_address_a` | Input     | `NB_ADDRESS` | Read address for port A.                         |
| `i_read_en_data_b` | Input     | 1            | Enable read on port B.                           |
| `i_read_address_b` | Input     | `NB_ADDRESS` | Read address for port B.                         |
| `i_write_en`       | Input     | 1            | Enable write.                                    |
| `i_write_address`  | Input     | `NB_ADDRESS` | Write address.                                   |
| `i_write_data`     | Input     | `NB_DATA`    | Data to write.                                   |
| `clock`            | Input     | 1            | System clock.                                    |

## Behavior

- **Write:** Synchronous on `posedge clock` — data is stored when `i_write_en` is asserted.
- **Read A / B:** Synchronous on `negedge clock` — data is captured when the respective `i_read_en` is asserted.
- **Initialization:** All `2^NB_ADDRESS` locations set to zero in an `initial` block.
- **FPGA inference:** The `(* ram_style = "block" *)` attribute instructs Vivado/ISE to map this to dedicated BRAM resources.

## Design Notes

- Using opposite clock edges for read and write avoids read-write conflicts on the same address within one cycle.
- Depth scales automatically with `NB_ADDRESS`; changing the parameter is the only modification needed for different memory sizes.