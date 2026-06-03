# TP3 — Memoria: registros y memoria esperados step por step

## Suposiciones

* Pipeline de 5 etapas: IF, ID, EX, MEM, WB.
* 1 step = 1 ciclo de clock.
* Los registros cambian cuando la instrucción llega a WB.
* Los stores (`sw`, `sb`, `sh`) cambian memoria en MEM.
* Todos los registros empiezan en 0.
* La memoria empieza en 0.
* `x0 / zero` siempre vale 0.
* RISC-V RV32 usa words de 32 bits.
* Se asume memoria little-endian.

---

# Recordatorio rápido

## Load

```text
memoria → registro
```

Ejemplo:

```asm
lw a0, 0(sp)
```

Lee memoria y escribe `a0`.

---

## Store

```text
registro → memoria
```

Ejemplo:

```asm
sw t1, 0(sp)
```

Toma el valor de `t1` y lo guarda en memoria.

---

# Tamaños

| Tipo     | Tamaño            |
| -------- | ----------------- |
| byte     | 8 bits = 1 byte   |
| halfword | 16 bits = 2 bytes |
| word     | 32 bits = 4 bytes |

---

# Tabla step por step

| Step | Instrucción relevante  | Cambia      | Valor esperado      | Qué significa                  |
| ---- | ---------------------- | ----------- | ------------------- | ------------------------------ |
| 1    | -                      | nada        | -                   | Pipeline empieza a llenarse    |
| 2    | -                      | nada        | -                   | Todavía no hay WB/MEM útil     |
| 3    | -                      | nada        | -                   | Todavía no hay WB/MEM útil     |
| 4    | -                      | nada        | -                   | Todavía no hay WB/MEM útil     |
| 5    | `addi sp, zero, 0`     | `sp / x2`   | `0x00000000`        | Base de memoria en 0           |
| 6    | `addi t0, zero, 0x41`  | `t0 / x5`   | `0x00000041` = 65   | Carga `'A'`                    |
| 7    | `addi t1, zero, -100`  | `t1 / x6`   | `0xFFFFFF9C` = -100 | Carga número negativo          |
| 8    | `sw t1, 0(sp)`         | `MEM[0..3]` | `0xFFFFFF9C`        | Guarda word en memoria         |
| 9    | `lw a0, 0(sp)`         | `a0 / x10`  | `0xFFFFFF9C` = -100 | Lee word desde memoria         |
| 10   | `sb t0, 4(sp)`         | `MEM[4]`    | `0x41`              | Guarda 1 byte                  |
| 11   | `addi t2, zero, -1`    | `t2 / x7`   | `0xFFFFFFFF` = -1   | Carga -1                       |
| 12   | `sb t2, 5(sp)`         | `MEM[5]`    | `0xFF`              | Guarda byte bajo de -1         |
| 13   | `lb a1, 4(sp)`         | `a1 / x11`  | `0x00000041` = 65   | Load byte signed positivo      |
| 14   | `lbu a2, 5(sp)`        | `a2 / x12`  | `0x000000FF` = 255  | Load byte unsigned             |
| 15   | `lb a3, 5(sp)`         | `a3 / x13`  | `0xFFFFFFFF` = -1   | Load byte signed negativo      |
| 16   | `addi t3, zero, 0x7FF` | `t3 / x28`  | `0x000007FF` = 2047 | Carga halfword positivo        |
| 17   | `sh t3, 8(sp)`         | `MEM[8..9]` | `0x07FF`            | Guarda halfword                |
| 18   | `lh a4, 8(sp)`         | `a4 / x14`  | `0x000007FF` = 2047 | Load halfword signed           |
| 19   | `lhu a5, 8(sp)`        | `a5 / x15`  | `0x000007FF` = 2047 | Load halfword unsigned         |
| 20   | `lbu a6, 0(sp)`        | `a6 / x16`  | `0x0000009C` = 156  | Lee byte bajo de -100 unsigned |
| 21   | `jal zero, end`        | nada        | -                   | Loop infinito                  |

---

# Estado acumulado por step

| Step | Estado esperado                     |
| ---- | ----------------------------------- |
| 1–4  | Registros y memoria en 0            |
| 5    | `sp = 0`                            |
| 6    | `t0 = 0x41`                         |
| 7    | `t1 = 0xFFFFFF9C`                   |
| 8    | `MEM[0..3] = 0xFFFFFF9C`            |
| 9    | `a0 = 0xFFFFFF9C`                   |
| 10   | `MEM[4] = 0x41`                     |
| 11   | `t2 = 0xFFFFFFFF`                   |
| 12   | `MEM[5] = 0xFF`                     |
| 13   | `a1 = 0x00000041`                   |
| 14   | `a2 = 0x000000FF`                   |
| 15   | `a3 = 0xFFFFFFFF`                   |
| 16   | `t3 = 0x000007FF`                   |
| 17   | `MEM[8..9] = 0x07FF`                |
| 18   | `a4 = 0x000007FF`                   |
| 19   | `a5 = 0x000007FF`                   |
| 20   | `a6 = 0x0000009C`                   |
| 21   | Estado final estable, entra en loop |

---

# Detalle de cada instrucción

## Step 5

```asm
addi sp, zero, 0
```

Hace:

```text
sp = 0 + 0
```

Entonces:

```text
sp = 0
```

`sp` se usa como base para acceder a memoria.

---

## Step 6

```asm
addi t0, zero, 0x41
```

Hace:

```text
t0 = 0x41
```

`0x41` en ASCII representa la letra `'A'`.

Decimal:

```text
0x41 = 65
```

---

## Step 7

```asm
addi t1, zero, -100
```

Carga `-100`.

En complemento a 2 de 32 bits:

```text
t1 = 0xFFFFFF9C
```

---

## Step 8

```asm
sw t1, 0(sp)
```

`sw` significa Store Word.

Guarda 32 bits desde un registro hacia memoria.

Como:

```text
sp = 0
```

la dirección efectiva es:

```text
0 + sp = 0
```

Entonces se guarda:

```text
MEM[0..3] = 0xFFFFFF9C
```

Como es little-endian, byte por byte queda:

| Dirección | Byte   |
| --------- | ------ |
| 0         | `0x9C` |
| 1         | `0xFF` |
| 2         | `0xFF` |
| 3         | `0xFF` |

---

## Step 9

```asm
lw a0, 0(sp)
```

`lw` significa Load Word.

Lee 32 bits desde memoria.

Dirección:

```text
0 + sp = 0
```

Lee:

```text
MEM[0..3] = 0xFFFFFF9C
```

Entonces:

```text
a0 = 0xFFFFFF9C
```

Decimal:

```text
a0 = -100
```

---

## Step 10

```asm
sb t0, 4(sp)
```

`sb` significa Store Byte.

Guarda solo 8 bits, es decir el byte bajo del registro.

Como:

```text
t0 = 0x00000041
```

se guarda:

```text
MEM[4] = 0x41
```

---

## Step 11

```asm
addi t2, zero, -1
```

Carga `-1`.

En 32 bits:

```text
t2 = 0xFFFFFFFF
```

---

## Step 12

```asm
sb t2, 5(sp)
```

Guarda solo el byte bajo de `t2`.

Como:

```text
t2 = 0xFFFFFFFF
```

el byte bajo es:

```text
0xFF
```

Entonces:

```text
MEM[5] = 0xFF
```

---

## Step 13

```asm
lb a1, 4(sp)
```

`lb` significa Load Byte signed.

Lee un byte desde:

```text
4 + sp = 4
```

La memoria tiene:

```text
MEM[4] = 0x41
```

Como `0x41` tiene bit de signo 0, es positivo.

Entonces se extiende así:

```text
a1 = 0x00000041
```

Decimal:

```text
a1 = 65
```

---

## Step 14

```asm
lbu a2, 5(sp)
```

`lbu` significa Load Byte Unsigned.

Lee:

```text
MEM[5] = 0xFF
```

Como es unsigned, rellena los bits altos con 0:

```text
a2 = 0x000000FF
```

Decimal:

```text
a2 = 255
```

---

## Step 15

```asm
lb a3, 5(sp)
```

`lb` significa Load Byte signed.

Lee:

```text
MEM[5] = 0xFF
```

Como signed, mira el bit más alto del byte:

```text
0xFF = 11111111
```

El bit de signo es 1, entonces hace sign extension:

```text
a3 = 0xFFFFFFFF
```

Decimal:

```text
a3 = -1
```

---

## Step 16

```asm
addi t3, zero, 0x7FF
```

Carga:

```text
t3 = 0x000007FF
```

Decimal:

```text
t3 = 2047
```

---

## Step 17

```asm
sh t3, 8(sp)
```

`sh` significa Store Halfword.

Guarda 16 bits.

Como:

```text
t3 = 0x000007FF
```

el halfword bajo es:

```text
0x07FF
```

Se guarda en:

```text
MEM[8..9]
```

En little-endian:

| Dirección | Byte   |
| --------- | ------ |
| 8         | `0xFF` |
| 9         | `0x07` |

---

## Step 18

```asm
lh a4, 8(sp)
```

`lh` significa Load Halfword signed.

Lee 16 bits:

```text
0x07FF
```

Como el bit de signo del halfword es 0, es positivo.

Entonces:

```text
a4 = 0x000007FF
```

Decimal:

```text
a4 = 2047
```

---

## Step 19

```asm
lhu a5, 8(sp)
```

`lhu` significa Load Halfword Unsigned.

Lee:

```text
0x07FF
```

Como es unsigned, rellena con ceros:

```text
a5 = 0x000007FF
```

En este caso da igual que `lh`, porque `0x07FF` es positivo.

---

## Step 20

```asm
lbu a6, 0(sp)
```

Lee 1 byte unsigned desde:

```text
0 + sp = 0
```

En memoria:

```text
MEM[0] = 0x9C
```

Ese es el byte menos significativo de `0xFFFFFF9C`.

Como `lbu` es unsigned:

```text
a6 = 0x0000009C
```

Decimal:

```text
a6 = 156
```

---

## Step 21

```asm
jal zero, end
```

Salta a `end`.

Como `rd = zero`, no escribe retorno.

El programa queda en loop infinito.

---

# Estado final esperado de registros

| Registro   | Valor decimal | Valor hexadecimal |
| ---------- | ------------: | ----------------- |
| `sp / x2`  |             0 | `0x00000000`      |
| `t0 / x5`  |            65 | `0x00000041`      |
| `t1 / x6`  |          -100 | `0xFFFFFF9C`      |
| `t2 / x7`  |            -1 | `0xFFFFFFFF`      |
| `t3 / x28` |          2047 | `0x000007FF`      |
| `a0 / x10` |          -100 | `0xFFFFFF9C`      |
| `a1 / x11` |            65 | `0x00000041`      |
| `a2 / x12` |           255 | `0x000000FF`      |
| `a3 / x13` |            -1 | `0xFFFFFFFF`      |
| `a4 / x14` |          2047 | `0x000007FF`      |
| `a5 / x15` |          2047 | `0x000007FF`      |
| `a6 / x16` |           156 | `0x0000009C`      |

---

# Estado final esperado de memoria

| Dirección | Valor  |
| --------- | ------ |
| `MEM[0]`  | `0x9C` |
| `MEM[1]`  | `0xFF` |
| `MEM[2]`  | `0xFF` |
| `MEM[3]`  | `0xFF` |
| `MEM[4]`  | `0x41` |
| `MEM[5]`  | `0xFF` |
| `MEM[8]`  | `0xFF` |
| `MEM[9]`  | `0x07` |

También puede verse agrupado como:

| Rango       | Valor lógico |
| ----------- | ------------ |
| `MEM[0..3]` | `0xFFFFFF9C` |
| `MEM[8..9]` | `0x07FF`     |

---

# Checks importantes en la debug unit

## 1. Stores modifican memoria, no registros

Estas instrucciones no deberían cambiar registros destino:

```asm
sw t1, 0(sp)
sb t0, 4(sp)
sb t2, 5(sp)
sh t3, 8(sp)
```

---

## 2. Loads modifican registros

Estas instrucciones sí escriben registros:

```asm
lw a0, 0(sp)
lb a1, 4(sp)
lbu a2, 5(sp)
lb a3, 5(sp)
lh a4, 8(sp)
lhu a5, 8(sp)
lbu a6, 0(sp)
```

---

## 3. Diferencia entre `lb` y `lbu`

Ambas leen 1 byte.

Pero:

```asm
lbu a2, 5(sp)
```

da:

```text
0x000000FF
```

mientras que:

```asm
lb a3, 5(sp)
```

da:

```text
0xFFFFFFFF
```

porque `lb` hace sign extension.

---

## 4. Diferencia entre `lh` y `lhu`

En este TP dan igual porque el halfword es positivo:

```text
0x07FF
```

Pero si el bit 15 fuera 1, `lh` extendería signo y `lhu` no.

---

## 5. Revisar little-endian

Después de:

```asm
sw t1, 0(sp)
```

con:

```text
t1 = 0xFFFFFF9C
```

la memoria byte a byte debería verse:

```text
MEM[0] = 0x9C
MEM[1] = 0xFF
MEM[2] = 0xFF
MEM[3] = 0xFF
```
