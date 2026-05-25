# Protocolo de Debug UART

La debug unit usa frames binarios simples sobre UART 115200 8N1. Todos los campos multi-byte se transmiten little-endian.

## Frame de comando

Cada comando normal enviado desde el host tiene 6 bytes:

| Byte | Campo | Descripcion |
|------|-------|-------------|
| 0 | `opcode` | Codigo de comando. |
| 1..4 | `payload` | Entero de 32 bits little-endian. |
| 5 | `checksum` | XOR de bytes 0..4. |

Checksum:

```text
checksum = opcode ^ payload[7:0] ^ payload[15:8] ^ payload[23:16] ^ payload[31:24]
```

## Frame de respuesta

Las respuestas normales tienen 5 bytes:

| Byte | Campo | Descripcion |
|------|-------|-------------|
| 0 | `status` | `0x00` OK, `0x01` ERROR, `0x02` BUSY. |
| 1..4 | `data` | Entero de 32 bits little-endian. |

Algunos comandos de dump envian primero un stream de bytes de datos y luego una respuesta normal de 5 bytes.

## Comandos

| Opcode | Nombre | Payload | Respuesta / stream |
|--------|--------|---------|--------------------|
| `0x01` | `LOAD_FW` | Ignorado en el frame inicial | Secuencia especial de carga, luego respuesta OK/ERROR. |
| `0x02` | `RUN` | Ignorado | Inicia CPU; respuesta normal con data `0`. |
| `0x03` | `STEP` | Cantidad de ciclos de pipeline; `0` equivale a `1` | Respuesta con PC al finalizar. |
| `0x04` | `HALT` | Ignorado | Detiene CPU; respuesta con PC actual. |
| `0x05` | `READ_REG` | Registro `0..31`, o `0xFF` para dump | Registro leido, o stream de 132 bytes + respuesta. |
| `0x06` | `READ_MEM` | Direccion de palabra, o `0xFFFFFFFF` para dump | Palabra leida, o stream de DMEM + respuesta. |
| `0x07` | `WRITE_REG` | Registro destino | Existe en RTL de debug, no conectado a nivel sistema actual. |
| `0x08` | `WRITE_MEM` | Direccion destino | Existe en RTL de debug, no conectado a nivel sistema actual. |
| `0x09` | `SET_BKP` | PC del breakpoint | Respuesta normal. |
| `0x0A` | `CLR_BKP` | PC del breakpoint | Respuesta normal. |
| `0x0B` | `RESET` | Ignorado | Pulso de reset de CPU; respuesta normal. |
| `0x0F` | `STATUS` | Ignorado | Bits de estado en `data`. |
| `0x10` | `READ_LATCH` | Ignorado | Stream de 45 bytes con registros de pipeline + respuesta. |

## LOAD_FW

`LOAD_FW` no usa solo el frame normal. La secuencia completa es:

1. Host envia frame de comando `CMD_LOAD_FW` con payload `0`.
2. Host envia `N` como entero de 32 bits little-endian, donde `N` es la cantidad de instrucciones.
3. Host envia `N` instrucciones RV32I de 32 bits, cada una little-endian.
4. FPGA responde con frame normal de 5 bytes.

Los clientes Python agregan por defecto una instruccion especial de halt al final del firmware:

```text
HALT_INST = 0x1A1A1A1A
```

Cuando la CPU ejecuta esa palabra, `du_master` detiene la ejecucion y marca la CPU como halted.

## STATUS

`CMD_STATUS` devuelve los flags de estado en `data`:

| Bit | Nombre | Significado |
|-----|--------|-------------|
| 0 | `running` | CPU corriendo. |
| 1 | `halted` | CPU detenida. |
| 2 | `bkp_hit` | Se alcanzo un breakpoint. |
| 31..3 | Reservado | Actualmente `0`. |

## Dumps

### READ_REG con payload `0xFF`

El hardware transmite 132 bytes y despues una respuesta normal:

| Bytes | Contenido |
|-------|-----------|
| `0..3` | PC actual, little-endian. |
| `4..131` | Registros `x0..x31`, 4 bytes cada uno, little-endian. |

`scripts/debug_client.py` implementa este flujo con el comando interactivo `rr 255` o `rr 0xFF`.

### READ_MEM con payload `0xFFFFFFFF`

El RTL soporta dump secuencial de DMEM. El tamano del stream es `2^NB_ADDR * 4` bytes, seguido por respuesta normal. Con `NB_ADDR = 8`, el stream es de 1024 bytes.

La shell Python actual expone lectura de una palabra con `rm <addr>`; no expone un comando de dump completo.

### READ_LATCH

`READ_LATCH` transmite 45 bytes con el estado de los registros IF/ID, ID/EX, EX/MEM y MEM/WB, seguido por respuesta normal. El layout exacto esta documentado en `modules/debug_unit/communication/docs/Pipeline Latch Transmitter.md`.

## Herramientas host

Shell interactiva Linux/macOS:

```bash
python3 scripts/debug_client.py /dev/ttyUSB0 115200
```

Carga directa en Windows:

```bash
python scripts/load_program_windows.py COM3 115200 code/bin/test_program.bin
```

## Limitaciones actuales

- `WRITE_REG` y `WRITE_MEM` no deben usarse a nivel sistema hasta conectar arbitraje de escritura en `cpu_core`.
- No hay byte de start-of-frame. Si el enlace queda desfasado, usar `sync` en la shell para limpiar buffers y verificar `CMD_STATUS`.
- `STEP` avanza ciclos de pipeline, no instrucciones arquitecturales completas.
