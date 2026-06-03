# TP2 — Registros esperados step por step

## Suposiciones

* Pipeline de 5 etapas: IF, ID, EX, MEM, WB.
* 1 step = 1 ciclo de clock.
* Los registros cambian recién cuando la instrucción llega a WB.
* Todos los registros empiezan en 0.
* `x0 / zero` siempre vale 0.
* No hay stalls esperados en este TP.

---

# Tabla step por step

| Step | Instrucción que llega a WB | Registro que cambia | Valor esperado       | Qué significa               |
| ---- | -------------------------- | ------------------- | -------------------- | --------------------------- |
| 1    | -                          | ninguno             | -                    | Pipeline empieza a llenarse |
| 2    | -                          | ninguno             | -                    | Todavía no hay WB           |
| 3    | -                          | ninguno             | -                    | Todavía no hay WB           |
| 4    | -                          | ninguno             | -                    | Todavía no hay WB           |
| 5    | `addi t0, zero, 0x0F`      | `t0 / x5`           | `0x0000000F` = 15    | Carga 15                    |
| 6    | `addi t1, zero, 0x36`      | `t1 / x6`           | `0x00000036` = 54    | Carga 54                    |
| 7    | `and t2, t0, t1`           | `t2 / x7`           | `0x00000006` = 6     | AND bit a bit               |
| 8    | `or t3, t0, t1`            | `t3 / x28`          | `0x0000003F` = 63    | OR bit a bit                |
| 9    | `xor t4, t0, t1`           | `t4 / x29`          | `0x00000039` = 57    | XOR bit a bit               |
| 10   | `andi t5, t1, 0x0F`        | `t5 / x30`          | `0x00000006` = 6     | AND con inmediato           |
| 11   | `ori t6, t0, 0x30`         | `t6 / x31`          | `0x0000003F` = 63    | OR con inmediato            |
| 12   | `xori s0, t0, 0xFF`        | `s0 / x8`           | `0x000000F0` = 240   | XOR con inmediato `0xFF`    |
| 13   | `addi s1, zero, -1`        | `s1 / x9`           | `0xFFFFFFFF` = -1    | Carga -1                    |
| 14   | `addi s2, zero, 2`         | `s2 / x18`          | `0x00000002` = 2     | Carga 2                     |
| 15   | `sll s3, t0, s2`           | `s3 / x19`          | `0x0000003C` = 60    | `15 << 2`                   |
| 16   | `srl s4, s1, s2`           | `s4 / x20`          | `0x3FFFFFFF`         | Shift lógico derecha        |
| 17   | `sra s5, s1, s2`           | `s5 / x21`          | `0xFFFFFFFF` = -1    | Shift aritmético derecha    |
| 18   | `srli s6, s1, 16`          | `s6 / x22`          | `0x0000FFFF` = 65535 | Shift lógico inmediato      |
| 19   | `srai s7, s1, 16`          | `s7 / x23`          | `0xFFFFFFFF` = -1    | Shift aritmético inmediato  |
| 20   | `jal zero, end`            | ninguno             | -                    | Loop infinito               |

---

# Ojo con `xori s0, t0, 0xFF`

En tu archivo el comentario dice:

```asm
xori  s0, t0, 0xFF       # s0 = 0xFFFFFFF0
```

Pero si el inmediato es `0x0FF`, como inmediato de 12 bits positivo, entonces:

```text
0x0000000F XOR 0x000000FF = 0x000000F0
```

Resultado:

```text
s0 = 0x000000F0
```

Para obtener:

```text
0xFFFFFFF0
```

el inmediato tendría que ser:

```asm
xori s0, t0, -1
```

porque `-1` sí se sign-extiende como `0xFFFFFFFF`.

Entonces, para validar tu core, revisaría esto con cuidado: **el valor esperado correcto para `xori s0, t0, 0xFF` debería ser `0x000000F0`, no `0xFFFFFFF0`**, salvo que tu assembler interprete ese literal de otra forma.

---

# Estado acumulado por step

| Step | Registros que ya deberían estar correctos |
| ---- | ----------------------------------------- |
| 1–4  | Todos en 0                                |
| 5    | `t0 = 15`                                 |
| 6    | `t1 = 54`                                 |
| 7    | `t2 = 6`                                  |
| 8    | `t3 = 63`                                 |
| 9    | `t4 = 57`                                 |
| 10   | `t5 = 6`                                  |
| 11   | `t6 = 63`                                 |
| 12   | `s0 = 0x000000F0`                         |
| 13   | `s1 = 0xFFFFFFFF`                         |
| 14   | `s2 = 2`                                  |
| 15   | `s3 = 60`                                 |
| 16   | `s4 = 0x3FFFFFFF`                         |
| 17   | `s5 = 0xFFFFFFFF`                         |
| 18   | `s6 = 0x0000FFFF`                         |
| 19   | `s7 = 0xFFFFFFFF`                         |
| 20   | Estado final estable, entra en loop       |

---

# Detalle de cada instrucción

## Step 5

```asm
addi t0, zero, 0x0F
```

Hace:

```text
t0 = 0 + 0x0F
```

Resultado:

```text
t0 = 15
```

---

## Step 6

```asm
addi t1, zero, 0x36
```

Hace:

```text
t1 = 0 + 0x36
```

Resultado:

```text
t1 = 54
```

---

## Step 7

```asm
and t2, t0, t1
```

Hace AND bit a bit.

```text
t0 = 0x0F = 0000 1111
t1 = 0x36 = 0011 0110
```

```text
0000 1111
0011 0110
---------
0000 0110
```

Resultado:

```text
t2 = 6
```

---

## Step 8

```asm
or t3, t0, t1
```

Hace OR bit a bit.

```text
0000 1111
0011 0110
---------
0011 1111
```

Resultado:

```text
t3 = 63
```

---

## Step 9

```asm
xor t4, t0, t1
```

Hace XOR bit a bit.

XOR da 1 cuando los bits son distintos.

```text
0000 1111
0011 0110
---------
0011 1001
```

Resultado:

```text
t4 = 57
```

---

## Step 10

```asm
andi t5, t1, 0x0F
```

Hace AND entre `t1` y el inmediato `0x0F`.

```text
0011 0110
0000 1111
---------
0000 0110
```

Resultado:

```text
t5 = 6
```

---

## Step 11

```asm
ori t6, t0, 0x30
```

Hace OR entre `t0` y `0x30`.

```text
0000 1111
0011 0000
---------
0011 1111
```

Resultado:

```text
t6 = 63
```

---

## Step 12

```asm
xori s0, t0, 0xFF
```

Hace XOR entre:

```text
t0 = 0x0000000F
imm = 0x000000FF
```

Resultado:

```text
0x0000000F XOR 0x000000FF = 0x000000F0
```

Entonces:

```text
s0 = 0x000000F0
```

---

## Step 13

```asm
addi s1, zero, -1
```

Carga -1.

En complemento a 2:

```text
-1 = 0xFFFFFFFF
```

Entonces:

```text
s1 = 0xFFFFFFFF
```

---

## Step 14

```asm
addi s2, zero, 2
```

Hace:

```text
s2 = 2
```

---

## Step 15

```asm
sll s3, t0, s2
```

Shift left logical.

Hace:

```text
s3 = t0 << s2
s3 = 15 << 2
```

Mover 2 bits a izquierda equivale a multiplicar por `2^2`.

```text
15 * 4 = 60
```

Entonces:

```text
s3 = 60
```

---

## Step 16

```asm
srl s4, s1, s2
```

Shift right logical.

`s1 = 0xFFFFFFFF`.

Como es lógico, rellena con ceros:

```text
11111111111111111111111111111111 >> 2
=
00111111111111111111111111111111
```

Resultado:

```text
s4 = 0x3FFFFFFF
```

---

## Step 17

```asm
sra s5, s1, s2
```

Shift right arithmetic.

`s1 = 0xFFFFFFFF`.

Como el bit de signo es 1, rellena con unos:

```text
11111111111111111111111111111111 >> 2
=
11111111111111111111111111111111
```

Resultado:

```text
s5 = 0xFFFFFFFF
```

---

## Step 18

```asm
srli s6, s1, 16
```

Shift right logical immediate.

```text
0xFFFFFFFF >> 16 = 0x0000FFFF
```

Resultado:

```text
s6 = 0x0000FFFF
```

---

## Step 19

```asm
srai s7, s1, 16
```

Shift right arithmetic immediate.

Como `s1` tiene bit de signo en 1:

```text
0xFFFFFFFF >>> 16 = 0xFFFFFFFF
```

Resultado:

```text
s7 = 0xFFFFFFFF
```

---

## Step 20

```asm
jal zero, end
```

Salta a `end`.

Como `rd = zero`, no escribe retorno.

El programa queda en loop infinito.

---

# Estado final esperado

| Registro   | Valor decimal | Valor hexadecimal |
| ---------- | ------------: | ----------------- |
| `t0 / x5`  |            15 | `0x0000000F`      |
| `t1 / x6`  |            54 | `0x00000036`      |
| `t2 / x7`  |             6 | `0x00000006`      |
| `t3 / x28` |            63 | `0x0000003F`      |
| `t4 / x29` |            57 | `0x00000039`      |
| `t5 / x30` |             6 | `0x00000006`      |
| `t6 / x31` |            63 | `0x0000003F`      |
| `s0 / x8`  |           240 | `0x000000F0`      |
| `s1 / x9`  |            -1 | `0xFFFFFFFF`      |
| `s2 / x18` |             2 | `0x00000002`      |
| `s3 / x19` |            60 | `0x0000003C`      |
| `s4 / x20` |    1073741823 | `0x3FFFFFFF`      |
| `s5 / x21` |            -1 | `0xFFFFFFFF`      |
| `s6 / x22` |         65535 | `0x0000FFFF`      |
| `s7 / x23` |            -1 | `0xFFFFFFFF`      |

---

# Checks importantes en la debug unit

## 1. `srl` y `sra` deben dar distinto

```asm
srl s4, s1, s2
sra s5, s1, s2
```

Deben dar:

```text
s4 = 0x3FFFFFFF
s5 = 0xFFFFFFFF
```

---

## 2. `srli` y `srai` deben dar distinto

```asm
srli s6, s1, 16
srai s7, s1, 16
```

Deben dar:

```text
s6 = 0x0000FFFF
s7 = 0xFFFFFFFF
```

---

## 3. `x0 / zero` siempre debe valer 0

Nunca debe cambiar.

---

## 4. No deberían aparecer stalls

Este TP no tiene loads ni branches condicionales.

---

## 5. Revisar el caso `xori`

El comentario del archivo espera `0xFFFFFFF0`, pero por ISA RISC-V con inmediato `0xFF` positivo, el resultado lógico esperado es:

```text
0x000000F0
```

Si querés `0xFFFFFFF0`, usar:

```asm
xori s0, t0, -1
```
