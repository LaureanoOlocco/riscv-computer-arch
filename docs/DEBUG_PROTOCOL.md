# UART Debug Protocol

The debug unit uses simple binary frames over UART 115200 8N1. All multi-byte fields are transmitted little-endian.

## Command Frame

Each normal command sent by the host has 6 bytes:

| Byte | Field | Description |
|------|-------|-------------|
| 0 | `opcode` | Command code. |
| 1..4 | `payload` | 32-bit little-endian integer. |
| 5 | `checksum` | XOR of bytes 0..4. |

Checksum:

```text
checksum = opcode ^ payload[7:0] ^ payload[15:8] ^ payload[23:16] ^ payload[31:24]
```

## Response Frame

Normal responses have 5 bytes:

| Byte | Field | Description |
|------|-------|-------------|
| 0 | `status` | `0x00` OK, `0x01` ERROR, `0x02` BUSY. |
| 1..4 | `data` | 32-bit little-endian integer. |

Some dump commands first send a data byte stream and then a normal 5-byte response.

## Commands

| Opcode | Name | Payload | Response / Stream |
|--------|------|---------|-------------------|
| `0x01` | `LOAD_FW` | Ignored in the initial frame | Special load sequence, then OK/ERROR response. |
| `0x02` | `RUN` | Ignored | Starts CPU; normal response with data `0`. |
| `0x03` | `STEP` | Number of pipeline cycles; `0` means `1` | Response with PC when done. |
| `0x04` | `HALT` | Ignored | Stops CPU; response with current PC. |
| `0x05` | `READ_REG` | Register `0..31`, or `0xFF` for dump | Register value, or 132-byte stream + response. |
| `0x06` | `READ_MEM` | Word address, or `0xFFFFFFFF` for dump | Memory word, or DMEM stream + response. |
| `0x07` | `WRITE_REG` | Destination register | Exists in debug RTL, not connected at current system level. |
| `0x08` | `WRITE_MEM` | Destination address | Exists in debug RTL, not connected at current system level. |
| `0x09` | `SET_BKP` | Breakpoint PC | Normal response. |
| `0x0A` | `CLR_BKP` | Breakpoint PC | Normal response. |
| `0x0B` | `RESET` | Ignored | CPU reset pulse; normal response. |
| `0x0F` | `STATUS` | Ignored | Status bits in `data`. |
| `0x10` | `READ_LATCH` | Ignored | 45-byte stream with pipeline registers + response. |

## LOAD_FW

`LOAD_FW` does not use only the normal frame. The full sequence is:

1. Host sends a `CMD_LOAD_FW` command frame with payload `0`.
2. Host sends `N` as a 32-bit little-endian integer, where `N` is the instruction count.
3. Host sends `N` 32-bit RV32I instructions, each little-endian.
4. FPGA responds with a normal 5-byte frame.

The Python clients append a special halt instruction to the firmware by default:

```text
HALT_INST = 0x1A1A1A1A
```

When the CPU executes that word, `du_master` stops execution and marks the CPU as halted.

## STATUS

`CMD_STATUS` returns status flags in `data`:

| Bit | Name | Meaning |
|-----|------|---------|
| 0 | `running` | CPU is running. |
| 1 | `halted` | CPU is halted. |
| 2 | `bkp_hit` | A breakpoint was reached. |
| 31..3 | Reserved | Currently `0`. |

## Dumps

### READ_REG with payload `0xFF`

Hardware transmits 132 bytes and then a normal response:

| Bytes | Contents |
|-------|----------|
| `0..3` | Current PC, little-endian. |
| `4..131` | Registers `x0..x31`, 4 bytes each, little-endian. |

`scripts/debug_client.py` implements this flow with the interactive command `rr 255` or `rr 0xFF`.

### READ_MEM with payload `0xFFFFFFFF`

The RTL supports a sequential DMEM dump. The stream size is `2^NB_ADDR * 4` bytes, followed by a normal response. With `NB_ADDR = 8`, the stream is 1024 bytes.

The current Python shell exposes single-word reads with `rm <addr>`; it does not expose a full-dump command.

### READ_LATCH

`READ_LATCH` transmits 45 bytes with IF/ID, ID/EX, EX/MEM, and MEM/WB register state, followed by a normal response. The exact layout is documented in `modules/debug_unit/communication/docs/Pipeline Latch Transmitter.md`.

## Host Tools

Interactive shell for Linux/macOS:

```bash
python3 scripts/debug_client.py /dev/ttyUSB0 115200
```

Direct loader for Windows:

```bash
python scripts/load_program_windows.py COM3 115200 code/bin/test_program.bin
```

## Current Limitations

- `WRITE_REG` and `WRITE_MEM` should not be used at system level until write arbitration is connected in `cpu_core`.
- There is no start-of-frame byte. If the link gets misaligned, use `sync` in the shell to clear buffers and verify `CMD_STATUS`.
- `STEP` advances pipeline cycles, not complete architectural instructions.
