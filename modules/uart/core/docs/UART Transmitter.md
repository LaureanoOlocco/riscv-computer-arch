# UART Transmitter

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-09

## Description

Oversampling UART transmitter. Loads a data byte on `i_tx_start`, serializes it LSB-first with a start bit and a stop bit, and drives the result on `o_tx`. Asserts `o_tx_done_tick` for one tick cycle after the stop bit completes. Idle line is held high.

## Parameters

| Parameter  | Default | Description                                      |
|------------|:-------:|--------------------------------------------------|
| `NB_DATA`  | `8`     | Number of data bits per frame.                   |
| `SM_TICK`  | `16`    | Oversampling ratio (ticks per bit period).       |

## Ports

| Name             | Direction | Width     | Description                                           |
|------------------|:---------:|:---------:|-------------------------------------------------------|
| `o_tx`           | Output    | 1         | Serial output line (idle high).                       |
| `o_tx_done_tick` | Output    | 1         | Pulsed for one tick after transmission completes.     |
| `i_data`         | Input     | `NB_DATA` | Parallel data to transmit.                            |
| `i_tx_start`     | Input     | 1         | Load and begin transmitting `i_data`.                 |
| `i_s_tick`       | Input     | 1         | Oversampling tick from `baud_rate_gen`.               |
| `i_rst`          | Input     | 1         | Synchronous active-high reset.                        |
| `clock`          | Input     | 1         | System clock.                                         |

## State Machine

| State        | Description                                                                        |
|--------------|------------------------------------------------------------------------------------|
| `STATE_IDLE` | Line held high. Latches `i_data` into `shifter_reg` on `i_tx_start`.              |
| `STATE_START`| Drives `o_tx` low for one full bit period (`SM_TICK` ticks).                      |
| `STATE_DATA` | Shifts out `NB_DATA` bits LSB-first; each bit lasts `SM_TICK` ticks.             |
| `STATE_STOP` | Drives `o_tx` high for one full bit period; asserts `o_tx_done_tick` at end.     |

## Behavior

- **Type:** Mealy FSM with combinational outputs; synchronous active-high reset.
- **Bit timing:** Each state counts `SM_TICK - 1` ticks before advancing, producing a bit period equal to exactly `SM_TICK` oversampling ticks.
- **Bit order:** LSB first — bit 0 of `i_data` is transmitted first.
- **Done tick:** `o_tx_done_tick` is asserted for one `i_s_tick` cycle at the end of the stop bit, signaling the controller that the transmitter is available for a new byte.
- **Idle output:** `o_tx` is driven from a registered `tx_reg`, initialized to `1` on reset, so the line is never floating.

## Design Notes

- `i_data` is captured into `shifter_reg` in `STATE_IDLE` when `i_tx_start` is asserted, decoupling the transmitter from changes on `i_data` during transmission.
- `NB_SAMPLE = $clog2(SM_TICK)` and `NB_BIT_CNT = $clog2(NB_DATA)` size the internal counters precisely to avoid wasted bits.
- The FSM uses the same two-always pattern as `uart_rx`: combinational next-state/output logic separate from registered state updates.
