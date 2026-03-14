# Register File

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco

## Description

Parameterizable synchronous register file with two asynchronous read ports and one synchronous write port. Write is gated on the falling clock edge and protected against writing to register `x0` (hardwired zero in RISC-V). Synchronous reset clears all registers.

## Parameters

| Parameter    | Default             | Description                                        |
|--------------|:-------------------:|----------------------------------------------------|
| `NB_DATA`    | `32`                | Width of each register.                            |
| `NB_ADDRESS` | `$clog2(NB_DATA)`   | Address width. Register count = `2^NB_ADDRESS`.    |

## Ports

| Name               | Direction | Width        | Description                                      |
|--------------------|:---------:|:------------:|--------------------------------------------------|
| `o_data_a`         | Output    | `NB_DATA`    | Read data from port A (asynchronous).            |
| `o_data_b`         | Output    | `NB_DATA`    | Read data from port B (asynchronous).            |
| `i_read_address_a` | Input     | `NB_ADDRESS` | Read address for port A.                         |
| `i_read_address_b` | Input     | `NB_ADDRESS` | Read address for port B.                         |
| `i_write_address`  | Input     | `NB_ADDRESS` | Write address.                                   |
| `i_write_data`     | Input     | `NB_DATA`    | Data to write.                                   |
| `i_write_enable`   | Input     | 1            | Enables write on the falling clock edge.         |
| `i_reset`          | Input     | 1            | Synchronous reset — clears all registers to 0.   |
| `clock`            | Input     | 1            | System clock.                                    |

## Behavior

- **Read:** Fully asynchronous — `o_data_a` and `o_data_b` reflect the current register values combinationally.
- **Write:** Synchronous on `negedge clock` — data is written when `i_write_enable` is asserted and the address is not zero.
- **x0 protection:** Writing to address `0` is silently ignored, preserving the RISC-V hardwired-zero invariant.
- **Reset:** On `negedge clock` with `i_reset`, all registers are cleared to zero.