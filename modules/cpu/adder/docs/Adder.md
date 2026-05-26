# Adder

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-12-13

## Description

Simple parameterizable combinational adder. Takes two `NB_ADDER`-bit operands and produces their sum as an `NB_ADDER`-bit output. The design contains no sequential logic or control signals — the result updates immediately whenever either input changes.

## Parameters

| Parameter  | Default | Description                                      |
|------------|:-------:|--------------------------------------------------|
| `NB_ADDER` | `32`    | Bit width of both input operands and the output. |


## Ports

| Name       | Direction | Width      | Description         |
|------------|:---------:|:----------:|---------------------|
| `o_result` | Output    | `NB_ADDER` | Sum result `a + b`. |
| `i_data_a` | Input     | `NB_ADDER` | First operand.      |
| `i_data_b` | Input     | `NB_ADDER` | Second operand.     |


## Block Diagram

```
        ┌───────────────────────┐
        │         adder         │
        │                       │
i_data_a│ ─────────┐            │
        │          ▼            │
        │        [ + ] ──────── │─── o_result
        │          ▲            │
i_data_b│ ─────────┘            │
        │                       │
        └───────────────────────┘
```

## Behavior

- **Type:** Purely combinational — no registers or clock signal.
- **Overflow:** If the sum exceeds `NB_ADDER` bits, the result is naturally truncated (unsigned wrap-around behavior).
- **Latency:** 0.


## Design Notes

- The file uses `` `default_nettype none `` to enforce explicit signal declarations and catch typographical errors at compile time.
- `NB_ADDER` allows the module to be reused for 8, 16, 32, or 64-bit additions without modifying the source.
- Intended for use as a **Program Counter (PC) adder** within a RISC-V pipeline, among other applications.