# TP1 — Registros esperados step por step

## Suposiciones

* Pipeline de 5 etapas: IF, ID, EX, MEM, WB.
* 1 step = 1 ciclo de clock.
* Los registros cambian recién cuando la instrucción llega a WB.
* Todos los registros empiezan en 0.
* `x0 / zero` siempre vale 0.
* No hay stalls en este TP.

---

# Tabla step por step

| Step | Instrucción que llega a WB | Registro que cambia | Valor esperado      | Qué significa                                     |
| ---- | -------------------------- | ------------------- | ------------------- | ------------------------------------------------- |
| 1    | -                          | ninguno             | -                   | Pipeline empieza a llenarse                       |
| 2    | -                          | ninguno             | -                   | Todavía no hay WB                                 |
| 3    | -                          | ninguno             | -                   | Todavía no hay WB                                 |
| 4    | -                          | ninguno             | -                   | Todavía no hay WB                                 |
| 5    | `lui a0, 1`                | `a0 / x10`          | `0x00001000` = 4096 | Carga `1 << 12`                                   |
| 6    | `auipc a1, 0`              | `a1 / x11`          | `0x00000004` = 4    | Guarda el PC de esa instrucción                   |
| 7    | `addi t0, zero, 20`        | `t0 / x5`           | 20                  | Suma `0 + 20`                                     |
| 8    | `addi t1, zero, 7`         | `t1 / x6`           | 7                   | Suma `0 + 7`                                      |
| 9    | `add t2, t0, t1`           | `t2 / x7`           | 27                  | `20 + 7`                                          |
| 10   | `sub t3, t0, t1`           | `t3 / x28`          | 13                  | `20 - 7`                                          |
| 11   | `add t4, t2, t3`           | `t4 / x29`          | 40                  | `27 + 13`                                         |
| 12   | `sub t5, t2, t3`           | `t5 / x30`          | 14                  | `27 - 13`                                         |
| 13   | `addi t6, t4, 10`          | `t6 / x31`          | 50                  | `40 + 10`                                         |
| 14   | `addi s0, zero, -3`        | `s0 / x8`           | `0xFFFFFFFD` = -3   | Inmediato negativo con sign extension             |
| 15   | `add s1, t0, s0`           | `s1 / x9`           | 17                  | `20 + (-3)`                                       |
| 16   | `sub s2, zero, t1`         | `s2 / x18`          | `0xFFFFFFF9` = -7   | `0 - 7`                                           |
| 17   | `slli s3, t1, 3`           | `s3 / x19`          | 56                  | `7 << 3`                                          |
| 18   | `addi a2, zero, 1`         | `a2 / x12`          | 1                   | Indicador de OK                                   |
| 19   | `jal zero, end`            | ninguno             | -                   | Salta a `end`, pero no escribe porque `rd = zero` |

---

# Estado acumulado por step

| Step | Registros que ya deberían estar correctos |
| ---- | ----------------------------------------- |
| 1–4  | Todos en 0                                |
| 5    | `a0 = 4096`                               |
| 6    | `a0 = 4096`, `a1 = 4`                     |
| 7    | `a0 = 4096`, `a1 = 4`, `t0 = 20`          |
| 8    | `t1 = 7`                                  |
| 9    | `t2 = 27`                                 |
| 10   | `t3 = 13`                                 |
| 11   | `t4 = 40`                                 |
| 12   | `t5 = 14`                                 |
| 13   | `t6 = 50`                                 |
| 14   | `s0 = -3`                                 |
| 15   | `s1 = 17`                                 |
| 16   | `s2 = -7`                                 |
| 17   | `s3 = 56`                                 |
| 18   | `a2 = 1`                                  |
| 19   | Estado final estable, entra en loop       |

---

# Detalle de cada instrucción

## Step 5

```asm
lui a0, 1
```

`lui` significa Load Upper Immediate.

No carga el valor `1` directamente. Carga:

```text
1 << 12 = 0x00001000
```

Entonces:

```text
a0 = 4096
```

---

## Step 6

```asm
auipc a1, 0
```

`auipc` hace:

```text
a1 = PC + (imm << 12)
```

Como el inmediato es 0:

```text
a1 = PC
```

La instrucción está en dirección `0x04`, entonces:

```text
a1 = 4
```

---

## Step 7

```asm
addi t0, zero, 20
```

Hace:

```text
t0 = 0 + 20
```

Entonces:

```text
t0 = 20
```

---

## Step 8

```asm
addi t1, zero, 7
```

Hace:

```text
t1 = 0 + 7
```

Entonces:

```text
t1 = 7
```

---

## Step 9

```asm
add t2, t0, t1
```

Hace:

```text
t2 = t0 + t1
t2 = 20 + 7
t2 = 27
```

Acá puede haber forwarding, porque `t0` y `t1` son valores recientes.

---

## Step 10

```asm
sub t3, t0, t1
```

Hace:

```text
t3 = 20 - 7
t3 = 13
```

---

## Step 11

```asm
add t4, t2, t3
```

Hace:

```text
t4 = 27 + 13
t4 = 40
```

Acá también puede haber forwarding, porque `t2` y `t3` son resultados recientes.

---

## Step 12

```asm
sub t5, t2, t3
```

Hace:

```text
t5 = 27 - 13
t5 = 14
```

---

## Step 13

```asm
addi t6, t4, 10
```

Hace:

```text
t6 = 40 + 10
t6 = 50
```

---

## Step 14

```asm
addi s0, zero, -3
```

Hace:

```text
s0 = 0 - 3
s0 = -3
```

En hexadecimal:

```text
s0 = 0xFFFFFFFD
```

Esto prueba sign extension.

---

## Step 15

```asm
add s1, t0, s0
```

Hace:

```text
s1 = 20 + (-3)
s1 = 17
```

---

## Step 16

```asm
sub s2, zero, t1
```

Hace:

```text
s2 = 0 - 7
s2 = -7
```

En hexadecimal:

```text
s2 = 0xFFFFFFF9
```

---

## Step 17

```asm
slli s3, t1, 3
```

Shift left logical immediate.

Hace:

```text
s3 = 7 << 3
```

Equivale a:

```text
7 * 2^3 = 56
```

Entonces:

```text
s3 = 56
```

---

## Step 18

```asm
addi a2, zero, 1
```

Hace:

```text
a2 = 1
```

Este registro suele usarse como indicador de que el test llegó correctamente al final.

---

## Step 19

```asm
jal zero, end
```

`jal` normalmente hace:

```text
rd = PC + 4
PC = target
```

Pero como `rd = zero`, no se guarda retorno.

Entonces:

```text
PC = end
```

y el programa queda en loop infinito.

---

# Estado final esperado

| Registro   | Valor decimal | Valor hexadecimal |
| ---------- | ------------: | ----------------- |
| `a0 / x10` |          4096 | `0x00001000`      |
| `a1 / x11` |             4 | `0x00000004`      |
| `a2 / x12` |             1 | `0x00000001`      |
| `t0 / x5`  |            20 | `0x00000014`      |
| `t1 / x6`  |             7 | `0x00000007`      |
| `t2 / x7`  |            27 | `0x0000001B`      |
| `t3 / x28` |            13 | `0x0000000D`      |
| `t4 / x29` |            40 | `0x00000028`      |
| `t5 / x30` |            14 | `0x0000000E`      |
| `t6 / x31` |            50 | `0x00000032`      |
| `s0 / x8`  |            -3 | `0xFFFFFFFD`      |
| `s1 / x9`  |            17 | `0x00000011`      |
| `s2 / x18` |            -7 | `0xFFFFFFF9`      |
| `s3 / x19` |            56 | `0x00000038`      |

---

# Checks importantes en la debug unit

## 1. Los registros cambian recién en WB

Si ves que `t0` cambia antes del step 7, probablemente estás mirando una señal interna y no el register file arquitectural.

---

## 2. `x0 / zero` siempre debe valer 0

Aunque una instrucción intente escribir en `zero`, debe ignorarse.

---

## 3. No debería haber stalls

TP1 no tiene loads ni branches condicionales.

---

## 4. Puede haber forwarding

Especialmente en:

```asm
add t2, t0, t1
add t4, t2, t3
```

El resultado final debe ser correcto aunque los registros fuente todavía no hayan llegado todos a WB.
