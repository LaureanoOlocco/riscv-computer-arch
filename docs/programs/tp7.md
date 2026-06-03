# TP7 — HALT y pipeline drain: registros esperados step por step

Archivo: `tp7_halt.s`

## Suposiciones

* Pipeline de 5 etapas: IF, ID, EX, MEM, WB.
* 1 step = 1 ciclo de clock.
* Los registros cambian cuando la instrucción llega a WB.
* Los stores cambian memoria en MEM.
* Todos los registros empiezan en 0.
* La memoria empieza en 0.
* `x0 / zero` siempre vale 0.
* Cuando aparece `halt`, la CPU no debe cortar instantáneamente las instrucciones ya dentro del pipeline.
* Después de `halt`, debe entrar en estado de `drain`.

---

# Objetivo del TP7

Este test valida:

* La instrucción `halt`.
* El estado de `drain`.
* Que el pipeline se vacíe correctamente.
* Que las últimas instrucciones lleguen a WB.
* Que los últimos registros no queden en 0.
* Que los stores pendientes se completen.
* Que el fetch se detenga después de `halt`.

---

# Concepto clave: pipeline drain

`drain` significa:

```text
dejar vaciar el pipeline
```

Cuando se detecta:

```asm
halt
```

la CPU debe:

| Acción                                         | ¿Debe ocurrir?                           |
| ---------------------------------------------- | ---------------------------------------- |
| Fetch de nuevas instrucciones                  | No                                       |
| Avance de instrucciones ya dentro del pipeline | Sí                                       |
| Writeback de instrucciones pendientes          | Sí                                       |
| Stores pendientes                              | Sí                                       |
| Detención final de CPU                         | Sí, recién cuando el pipeline está vacío |

---

# Código del programa

```asm
addi  sp, zero, 0
addi  t0, zero, 1
addi  t1, zero, 2
addi  t2, zero, 3

add   t3, t0, t1
add   t4, t2, t3
add   t5, t3, t4

sw    t5, 0(sp)
lw    a0, 0(sp)

addi  a1, a0, 1
addi  a2, a1, 1
addi  a3, a2, 1
addi  a4, a3, 1

add   a5, a4, t0

halt
```

---

# Tabla step por step

| Step | Instrucción relevante | Cambia      | Valor esperado | Qué significa                                    |
| ---- | --------------------- | ----------- | -------------- | ------------------------------------------------ |
| 1    | -                     | nada        | -              | Pipeline empieza a llenarse                      |
| 2    | -                     | nada        | -              | Todavía no hay WB/MEM útil                       |
| 3    | -                     | nada        | -              | Todavía no hay WB/MEM útil                       |
| 4    | -                     | nada        | -              | Todavía no hay WB/MEM útil                       |
| 5    | `addi sp, zero, 0`    | `sp / x2`   | `0`            | Base de memoria                                  |
| 6    | `addi t0, zero, 1`    | `t0 / x5`   | `1`            | Carga 1                                          |
| 7    | `addi t1, zero, 2`    | `t1 / x6`   | `2`            | Carga 2                                          |
| 8    | `addi t2, zero, 3`    | `t2 / x7`   | `3`            | Carga 3                                          |
| 9    | `add t3, t0, t1`      | `t3 / x28`  | `3`            | `1 + 2`                                          |
| 10   | `add t4, t2, t3`      | `t4 / x29`  | `6`            | `3 + 3`                                          |
| 11   | `add t5, t3, t4`      | `t5 / x30`  | `9`            | `3 + 6`                                          |
| 12   | `sw t5, 0(sp)`        | `MEM[0..3]` | `9`            | Store del valor calculado                        |
| 13   | `lw a0, 0(sp)`        | `a0 / x10`  | `9`            | Load desde memoria                               |
| 14   | `addi a1, a0, 1`      | `a1 / x11`  | `10`           | `9 + 1`                                          |
| 15   | `addi a2, a1, 1`      | `a2 / x12`  | `11`           | `10 + 1`                                         |
| 16   | `addi a3, a2, 1`      | `a3 / x13`  | `12`           | `11 + 1`                                         |
| 17   | `addi a4, a3, 1`      | `a4 / x14`  | `13`           | `12 + 1`                                         |
| 18   | `add a5, a4, t0`      | `a5 / x15`  | `14`           | `13 + 1`                                         |
| 19   | `halt` detectado      | estado CPU  | `DRAIN`        | Se detiene fetch, pero pipeline sigue vaciándose |
| 20+  | drain                 | pipeline    | vacío          | Terminan instrucciones pendientes                |

---

# Nota importante sobre los steps de HALT

Dependiendo de cuándo tu core detecta `halt`, el número exacto de steps después del step 19 puede variar.

Lo importante es:

```text
halt no debe impedir que a1, a2, a3, a4 y a5 terminen de escribirse
```

Si la CPU entra en HALTED demasiado pronto, los últimos registros pueden quedar incorrectos.

---

# Estado acumulado por step

| Step | Estado esperado                 |
| ---- | ------------------------------- |
| 1–4  | Registros y memoria en 0        |
| 5    | `sp = 0`                        |
| 6    | `t0 = 1`                        |
| 7    | `t1 = 2`                        |
| 8    | `t2 = 3`                        |
| 9    | `t3 = 3`                        |
| 10   | `t4 = 6`                        |
| 11   | `t5 = 9`                        |
| 12   | `MEM[0..3] = 9`                 |
| 13   | `a0 = 9`                        |
| 14   | `a1 = 10`                       |
| 15   | `a2 = 11`                       |
| 16   | `a3 = 12`                       |
| 17   | `a4 = 13`                       |
| 18   | `a5 = 14`                       |
| 19   | `halt` detectado, entra a drain |
| 20+  | Pipeline vacío, CPU detenida    |

---

# Detalle de cada instrucción

## Step 5

```asm
addi sp, zero, 0
```

Inicializa:

```text
sp = 0
```

Se usa como base de memoria.

---

## Step 6

```asm
addi t0, zero, 1
```

Carga:

```text
t0 = 1
```

---

## Step 7

```asm
addi t1, zero, 2
```

Carga:

```text
t1 = 2
```

---

## Step 8

```asm
addi t2, zero, 3
```

Carga:

```text
t2 = 3
```

---

## Step 9

```asm
add t3, t0, t1
```

Hace:

```text
t3 = 1 + 2
```

Resultado:

```text
t3 = 3
```

---

## Step 10

```asm
add t4, t2, t3
```

Hace:

```text
t4 = 3 + 3
```

Resultado:

```text
t4 = 6
```

---

## Step 11

```asm
add t5, t3, t4
```

Hace:

```text
t5 = 3 + 6
```

Resultado:

```text
t5 = 9
```

---

## Step 12

```asm
sw t5, 0(sp)
```

Guarda un word de 32 bits en memoria.

Dirección:

```text
sp + 0 = 0
```

Entonces:

```text
MEM[0..3] = 9
```

En hexadecimal:

```text
9 = 0x00000009
```

Little-endian byte a byte:

| Dirección | Byte   |
| --------- | ------ |
| `MEM[0]`  | `0x09` |
| `MEM[1]`  | `0x00` |
| `MEM[2]`  | `0x00` |
| `MEM[3]`  | `0x00` |

---

## Step 13

```asm
lw a0, 0(sp)
```

Lee:

```text
MEM[0..3] = 9
```

Entonces:

```text
a0 = 9
```

---

# Cadena final antes del HALT

Esta parte es la más importante del TP:

```asm
addi a1, a0, 1
addi a2, a1, 1
addi a3, a2, 1
addi a4, a3, 1
add  a5, a4, t0
halt
```

Está hecha para verificar que las últimas instrucciones completen WB antes de que la CPU quede detenida.

---

## Step 14

```asm
addi a1, a0, 1
```

Hace:

```text
a1 = 9 + 1
```

Resultado:

```text
a1 = 10
```

---

## Step 15

```asm
addi a2, a1, 1
```

Hace:

```text
a2 = 10 + 1
```

Resultado:

```text
a2 = 11
```

---

## Step 16

```asm
addi a3, a2, 1
```

Hace:

```text
a3 = 11 + 1
```

Resultado:

```text
a3 = 12
```

---

## Step 17

```asm
addi a4, a3, 1
```

Hace:

```text
a4 = 12 + 1
```

Resultado:

```text
a4 = 13
```

---

## Step 18

```asm
add a5, a4, t0
```

Hace:

```text
a5 = 13 + 1
```

Resultado:

```text
a5 = 14
```

---

## Step 19

```asm
halt
```

Cuando se detecta `halt`, la CPU debería entrar en estado de `drain`.

Eso significa:

```text
no fetch nuevo, pero las instrucciones ya dentro del pipeline siguen avanzando
```

---

# Qué debería hacer DRAIN

Una FSM típica:

```text
RUNNING
   ↓
HALT detectado
   ↓
DRAIN
   ↓
pipeline vacío
   ↓
HALTED
```

---

# Cómo se ve conceptualmente

Ejemplo conceptual cuando `halt` aparece en IF:

| Ciclo | IF     | ID       | EX        | MEM       | WB        |
| ----- | ------ | -------- | --------- | --------- | --------- |
| N     | `halt` | `add a5` | `addi a4` | `addi a3` | `addi a2` |
| N+1   | -      | `halt`   | `add a5`  | `addi a4` | `addi a3` |
| N+2   | -      | -        | `halt`    | `add a5`  | `addi a4` |
| N+3   | -      | -        | -         | `halt`    | `add a5`  |
| N+4   | -      | -        | -         | -         | `halt`    |
| N+5   | vacío  | vacío    | vacío     | vacío     | vacío     |

Lo importante es que `add a5` llegue a WB y escriba:

```text
a5 = 14
```

---

# Estado final esperado de registros

| Registro   | Valor decimal | Valor hexadecimal |
| ---------- | ------------: | ----------------- |
| `sp / x2`  |             0 | `0x00000000`      |
| `t0 / x5`  |             1 | `0x00000001`      |
| `t1 / x6`  |             2 | `0x00000002`      |
| `t2 / x7`  |             3 | `0x00000003`      |
| `t3 / x28` |             3 | `0x00000003`      |
| `t4 / x29` |             6 | `0x00000006`      |
| `t5 / x30` |             9 | `0x00000009`      |
| `a0 / x10` |             9 | `0x00000009`      |
| `a1 / x11` |            10 | `0x0000000A`      |
| `a2 / x12` |            11 | `0x0000000B`      |
| `a3 / x13` |            12 | `0x0000000C`      |
| `a4 / x14` |            13 | `0x0000000D`      |
| `a5 / x15` |            14 | `0x0000000E`      |

---

# Estado final esperado de memoria

| Dirección | Byte   |
| --------- | ------ |
| `MEM[0]`  | `0x09` |
| `MEM[1]`  | `0x00` |
| `MEM[2]`  | `0x00` |
| `MEM[3]`  | `0x00` |

Agrupado:

| Rango       | Valor lógico |
| ----------- | ------------ |
| `MEM[0..3]` | `9`          |

---

# Checks importantes en la debug unit

## 1. HALT no debe cortar WB

Los registros finales deben quedar:

```text
a1 = 10
a2 = 11
a3 = 12
a4 = 13
a5 = 14
```

Si alguno queda en 0, el drain está mal.

---

## 2. Fetch debe detenerse

Después de detectar `halt`, no deberían fetchearse instrucciones nuevas.

---

## 3. El pipeline debe vaciarse

Deben ir quedando vacías las etapas:

```text
IF → ID → EX → MEM → WB
```

hasta que no haya instrucciones válidas.

---

## 4. Stores pendientes deben completarse

La memoria debe contener:

```text
MEM[0..3] = 9
```

---

## 5. `x0 / zero` siempre debe valer 0

Nunca debe modificarse.
