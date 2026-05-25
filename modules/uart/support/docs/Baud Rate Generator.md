# Baud Rate Generator

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-09

## Description

Generates a periodic oversampling tick for the UART RX and TX state machines. Counts clock cycles up to a computed divisor and asserts `o_tick` for one cycle when the count wraps. The divisor is derived from the system clock frequency, the target baud rate, and the oversampling ratio, making the generator fully parameterizable without manual calculation.

## Parameters

| Parameter    | Default       | Description                                                   |
|--------------|:-------------:|---------------------------------------------------------------|
| `NB_COUNTER` | `9`           | Width of the internal counter register.                       |
| `CLK_FREQ`   | `100_000_000` | System clock frequency in Hz.                                 |
| `BAUD_RATE`  | `115_200`     | Target baud rate in bps.                                      |
| `SM_TICK`    | `16`          | Oversampling ratio (ticks per bit period).                    |

## Ports

| Name        | Direction | Width        | Description                                          |
|-------------|:---------:|:------------:|------------------------------------------------------|
| `o_counter` | Output    | `NB_COUNTER` | Current value of the free-running counter.           |
| `o_tick`    | Output    | 1            | Oversampling tick — high for one cycle per period.   |
| `i_rst`     | Input     | 1            | Asynchronous active-high reset.                      |
| `clock`     | Input     | 1            | System clock.                                        |

## Divisor Calculation

```
DIVISOR = CLK_FREQ / (BAUD_RATE × SM_TICK)
```

With the default parameters: `100_000_000 / (115_200 × 16) ≈ 54`. `o_tick` is thus asserted once every 54 clock cycles, producing 16 ticks per bit period at 115 200 bps.

## Behavior

- **Type:** Synchronous counter with asynchronous reset.
- **Tick generation:** The counter increments every clock cycle. When it reaches `DIVISOR - 1`, it resets to zero and `o_tick` is asserted for exactly one clock cycle.
- **Reset:** Asynchronous — counter and tick are cleared immediately on `i_rst` assertion.

## Design Notes

- `NB_COUNTER` must be wide enough to hold `DIVISOR - 1`. At 100 MHz / 115 200 bps × 16, `DIVISOR ≈ 54`, which fits in 6 bits; the default of 9 bits provides margin for lower baud rates or higher clock frequencies.
- `o_counter` is exposed for observability but is not consumed by any other module in the default design.
