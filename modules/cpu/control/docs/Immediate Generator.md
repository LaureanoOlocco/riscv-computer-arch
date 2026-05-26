# Immediate Generator

**Project:** RISC-V Computer Architecture  
**Authors:** Sofía Avalos · Laureano Olocco  
**Date:** 2025-12-13

## Description

Extracts and sign-extends the immediate value embedded in a RISC-V instruction word. Supports all six standard instruction formats. The R-Type format carries no immediate and always produces zero.

## Parameters

| Parameter | Default | Description                          |
|-----------|:-------:|--------------------------------------|
| `NB_DATA` | `32`    | Width of the instruction and output. |

## Ports

| Name            | Direction | Width     | Description                                      |
|-----------------|:---------:|:---------:|--------------------------------------------------|
| `o_immediate`   | Output    | `NB_DATA` | Sign-extended (or zero-padded) immediate value.  |
| `i_instruction` | Input     | `NB_DATA` | Full 32-bit instruction word.                    |

## Immediate Encoding per Format

| Format  | Opcode       | Bits extracted                                          | Extension  |
|---------|--------------|---------------------------------------------------------|------------|
| R-Type  | `7'b0110011` | None                                                    | Zero       |
| I-Type  | `7'b0010011` / `7'b0000011` / `7'b1100111` | `[31:20]`              | Sign `[31]`|
| S-Type  | `7'b0100011` | `[31:25]` \| `[11:7]`                                   | Sign `[31]`|
| B-Type  | `7'b1100011` | `[31]`, `[7]`, `[30:25]`, `[11:8]`, implicit `0`       | Sign `[31]`|
| U-Type  | `7'b0110111` | `[31:12]` with 12 zero LSBs                             | None       |
| J-Type  | `7'b1101111` | `[31]`, `[19:12]`, `[20]`, `[30:21]`, implicit `0`     | Sign `[31]`|

## Behavior

- **Type:** Purely combinational (`always @(*)`).
- **Selection:** Opcode field (`i_instruction[6:0]`) selects the extraction and sign-extension rule.
- **Default:** Unrecognized opcodes produce all-zero output.
- **Latency:** 0.

## Design Notes

- B-Type and J-Type immediates are always even (LSB forced to 0) because RISC-V branches and jumps target half-word-aligned addresses.
- U-Type forces the lower 12 bits to zero, as the immediate occupies the upper 20 bits of the word (used by `LUI` / `AUIPC`).