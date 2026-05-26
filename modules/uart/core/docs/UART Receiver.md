# UART Receiver

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-09

## Description

Oversampling UART receiver. Detects the start bit, samples each data bit at the center of its bit period using a tick from `baud_rate_gen`, and assembles the received bits into a data word. Asserts `o_rx_done_tick` for one tick cycle after the stop bit is confirmed.

## Parameters

| Parameter  | Default | Description                                               |
|------------|:-------:|-----------------------------------------------------------|
| `NB_DATA`  | `8`     | Number of data bits per frame.                            |
| `SM_TICK`  | `16`    | Oversampling ratio (ticks per bit period).                |

## Ports

| Name             | Direction | Width     | Description                                          |
|------------------|:---------:|:---------:|------------------------------------------------------|
| `o_data`         | Output    | `NB_DATA` | Assembled data word (valid when `o_rx_done_tick` = 1).|
| `o_rx_done_tick` | Output    | 1         | Pulsed for one tick after a complete frame is received.|
| `i_rx`           | Input     | 1         | Serial input line (idle high).                       |
| `i_s_tick`       | Input     | 1         | Oversampling tick from `baud_rate_gen`.              |
| `i_rst`          | Input     | 1         | Synchronous active-high reset.                       |
| `clock`          | Input     | 1         | System clock.                                        |

## State Machine

| State        | Description                                                                          |
|--------------|--------------------------------------------------------------------------------------|
| `STATE_IDLE` | Waits for `i_rx` to go low (start bit detected). Transitions immediately.           |
| `STATE_START`| Counts `SM_TICK/2 - 1` ticks to align sampling to the center of the start bit.     |
| `STATE_DATA` | Samples `i_rx` at each `SM_TICK - 1` tick boundary; shifts bits into `bits_reg`.   |
| `STATE_STOP` | Waits for the stop bit; asserts `o_rx_done_tick` and returns to `STATE_IDLE`.       |

## Behavior

- **Type:** Mealy FSM with combinational outputs; synchronous active-high reset.
- **Oversampling:** The receiver samples each bit `SM_TICK` ticks after the previous sample. The start bit is aligned by waiting `SM_TICK/2` ticks first, centering all subsequent samples within their respective bit windows.
- **Bit order:** LSB first — the first data bit received is placed in bit 0 of `o_data`.
- **Done tick:** `o_rx_done_tick` is asserted for exactly one `i_s_tick` cycle in `STATE_STOP`, which is compatible with direct connection to a FIFO write enable.

## Design Notes

- `NB_SAMPLE = $clog2(SM_TICK)` and `NB_BIT_CNT = $clog2(NB_DATA)` are derived parameters used to size the internal counters precisely.
- The FSM is purely combinational (`always @(*)`); all state and counter registers are updated on `posedge clock`. This two-always pattern keeps next-state logic and register updates clearly separated.
