# Instruction Memory Loader

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-02

## Description

Loads a program into instruction memory via UART. First receives a 32-bit instruction count (little-endian), then receives that many 32-bit instruction words and writes them sequentially to IMEM starting at address 0. Asserts `o_done` after the last word is written.

## Parameters

| Parameter      | Default | Description                        |
|----------------|:-------:|------------------------------------|
| `NB_DATA`      | `32`    | Width of the memory data bus.      |
| `NB_ADDR`      | `8`     | Width of the memory address bus.   |
| `NB_UART_DATA` | `8`     | Width of each UART byte.           |

## Ports

| Name          | Direction | Width          | Description                                        |
|---------------|:---------:|:--------------:|----------------------------------------------------|
| `o_done`      | Output    | 1              | Asserted for one cycle after the last write.       |
| `o_mem_wr`    | Output    | 1              | Instruction memory write enable.                   |
| `o_mem_waddr` | Output    | `NB_ADDR`      | Instruction memory write address.                  |
| `o_mem_wdata` | Output    | `NB_DATA`      | Instruction memory write data.                     |
| `i_start`     | Input     | 1              | Start pulse from `du_master`.                      |
| `i_rx_done`   | Input     | 1              | UART byte received pulse.                          |
| `i_rx_data`   | Input     | `NB_UART_DATA` | Received UART byte.                                |
| `i_rst`       | Input     | 1              | Synchronous active-high reset.                     |
| `clk`         | Input     | 1              | System clock.                                      |

## State Machine

| State       | Description                                                                       |
|-------------|-----------------------------------------------------------------------------------|
| `IDLE`      | Waits for `i_start`. Resets all internal registers on entry.                     |
| `RECV_SIZE` | Receives 4 bytes and assembles them into `size_reg` (instruction count, LE).     |
| `RECV_INST` | Receives 4 bytes and assembles them into `word_reg` (one instruction word, LE).  |
| `WRITE_MEM` | Writes `word_reg` to IMEM, advances address. Returns to `RECV_INST` or `IDLE`.  |

## Behavior

- **Type:** One-hot FSMD with combinational output logic; synchronous active-high reset.
- **Framing:** The first 4 bytes received encode the number of instructions as a 32-bit little-endian integer (`size_reg`). Subsequent groups of 4 bytes are individual instruction words.
- **Byte assembly:** Within both `RECV_SIZE` and `RECV_INST`, a 2-bit `byte_counter` routes each incoming byte to its correct 8-bit lane in the target register.
- **Termination:** After each `WRITE_MEM`, the next address (`mem_addr_reg + 1`) is compared against `size_reg`. When they are equal, the FSM returns to `IDLE` and asserts `o_done`; otherwise it returns to `RECV_INST` for the next word.
- **Done pulse:** `o_done` is asserted simultaneously with the final `o_mem_wr` in `WRITE_MEM`.

## Design Notes

- `word_reg` is cleared to zero at the start of each `WRITE_MEM` cycle, ensuring no residual data from the previous instruction contaminates a partially received word if the stream is interrupted.
- The size comparison uses zero-extension (`{(NB_DATA-NB_ADDR){1'b0}, mem_addr_reg + 1}`) to avoid width mismatch warnings between the `NB_ADDR`-wide address and the `NB_DATA`-wide size register.
