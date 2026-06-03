# TP6 — Hazards y forwarding: registros esperados step por step

Archivo: `tp6_hazard.s`

## Suposiciones

* Pipeline de 5 etapas: IF, ID, EX, MEM, WB.
* 1 step = 1 ciclo de clock.
* Los registros cambian cuando la instrucción llega a WB.
* Los stores cambian memoria en MEM.
* Todos los registros empiezan en 0.
* La memoria empieza en 0.
* `x0 / zero` siempre vale 0.
* Este TP sí debe mostrar forwarding.
* Este TP sí debe mostrar al menos un stall/bubble por load-use hazard.

---

# Objetivo del TP6

Este test valida:

* RAW hazards
* Forwarding EX → EX
* Forwarding MEM → EX
* Store después de resultado reciente
* Load-use hazard
* Stall / bubble
* Correcta escritura y lectura de memoria

---

# Conceptos clave

## RAW hazard

RAW significa:

```text
Read After Write
```

Ocurre cuando una instrucción necesita leer un registro que una instrucción anterior todavía no terminó de escribir.

Ejemplo:

```asm
add  t2, t0, t1
addi t3, t2, 7
```

`addi` necesita `t2`, pero `add` todavía no llegó a WB.

---

## Forwarding

Forwarding significa pasar el resultado directamente entre etapas del pipeline, sin esperar a que llegue a WB.

Ejemplo:

```text
resultado en EX/MEM → entrada de ALU en EX
```

---

## Load-use hazard

Caso más crítico:

```asm
lw    t5, 0(sp)
addi  t6, t5, 1
```

El `lw` recién tiene el dato después de MEM, pero el `addi` lo necesita en EX.

Entonces normalmente se necesita:

```text
1 stall + forwarding
```

---

# Código del programa

```asm
addi  sp, zero, 0
addi  t0, zero, 10
addi  t1, zero, 3
add   t2, t0, t1
addi  t3, t2, 7
sub   t4, t3, t0
sw    t4, 0(sp)
lw    t5, 0(sp)
addi  t6, t5, 1
add   s0, t5, t6
sw    s0, 4(sp)
lw    s1, 4(sp)
sub   s2, s0, t6
addi  a0, zero, 1
end:
jal   zero, end
```

---

# Tabla step por step

## Nota importante

Este programa tiene un stall por:

```asm
lw t5, 0(sp)
addi t6, t5, 1
```

Por eso, a diferencia de TP1/TP2/TP3, aparece un step extra sin escritura útil.

---

| Step | Instrucción relevante | Cambia      | Valor esperado | Qué significa                    |
| ---- | --------------------- | ----------- | -------------- | -------------------------------- |
| 1    | -                     | nada        | -              | Pipeline empieza a llenarse      |
| 2    | -                     | nada        | -              | Todavía no hay WB/MEM útil       |
| 3    | -                     | nada        | -              | Todavía no hay WB/MEM útil       |
| 4    | -                     | nada        | -              | Todavía no hay WB/MEM útil       |
| 5    | `addi sp, zero, 0`    | `sp / x2`   | `0`            | Base de memoria                  |
| 6    | `addi t0, zero, 10`   | `t0 / x5`   | `10`           | Carga 10                         |
| 7    | `addi t1, zero, 3`    | `t1 / x6`   | `3`            | Carga 3                          |
| 8    | `add t2, t0, t1`      | `t2 / x7`   | `13`           | `10 + 3`, con forwarding         |
| 9    | `addi t3, t2, 7`      | `t3 / x28`  | `20`           | `13 + 7`, usa forwarding         |
| 10   | `sub t4, t3, t0`      | `t4 / x29`  | `10`           | `20 - 10`, usa forwarding        |
| 11   | `sw t4, 0(sp)`        | `MEM[0..3]` | `10`           | Store del resultado reciente     |
| 12   | `lw t5, 0(sp)`        | `t5 / x30`  | `10`           | Load desde memoria               |
| 13   | bubble/stall          | nada        | -              | Stall por load-use hazard        |
| 14   | `addi t6, t5, 1`      | `t6 / x31`  | `11`           | Usa dato de `lw` luego del stall |
| 15   | `add s0, t5, t6`      | `s0 / x8`   | `21`           | `10 + 11`, forwarding            |
| 16   | `sw s0, 4(sp)`        | `MEM[4..7]` | `21`           | Store de resultado reciente      |
| 17   | `lw s1, 4(sp)`        | `s1 / x9`   | `21`           | Load desde memoria               |
| 18   | `sub s2, s0, t6`      | `s2 / x18`  | `10`           | `21 - 11`                        |
| 19   | `addi a0, zero, 1`    | `a0 / x10`  | `1`            | Test OK                          |
| 20   | `jal zero, end`       | PC          | `end`          | Loop infinito                    |

---

# Estado acumulado por step

| Step | Estado esperado                     |
| ---- | ----------------------------------- |
| 1–4  | Registros y memoria en 0            |
| 5    | `sp = 0`                            |
| 6    | `t0 = 10`                           |
| 7    | `t1 = 3`                            |
| 8    | `t2 = 13`                           |
| 9    | `t3 = 20`                           |
| 10   | `t4 = 10`                           |
| 11   | `MEM[0..3] = 10`                    |
| 12   | `t5 = 10`                           |
| 13   | Sin cambios, bubble/stall           |
| 14   | `t6 = 11`                           |
| 15   | `s0 = 21`                           |
| 16   | `MEM[4..7] = 21`                    |
| 17   | `s1 = 21`                           |
| 18   | `s2 = 10`                           |
| 19   | `a0 = 1`                            |
| 20   | Estado final estable, loop infinito |

---

# Detalle de cada instrucción

## Step 5

```asm
addi sp, zero, 0
```

Inicializa `sp` en 0.

```text
sp = 0
```

Se usa como base para acceder a memoria.

---

## Step 6

```asm
addi t0, zero, 10
```

Carga:

```text
t0 = 10
```

---

## Step 7

```asm
addi t1, zero, 3
```

Carga:

```text
t1 = 3
```

---

## Step 8

```asm
add t2, t0, t1
```

Hace:

```text
t2 = 10 + 3
```

Resultado:

```text
t2 = 13
```

### Importante

`t1` fue generado recientemente, por lo que puede requerir forwarding.

---

## Step 9

```asm
addi t3, t2, 7
```

Hace:

```text
t3 = 13 + 7
```

Resultado:

```text
t3 = 20
```

### Importante

`t2` viene de la instrucción anterior. Esto prueba forwarding EX → EX.

---

## Step 10

```asm
sub t4, t3, t0
```

Hace:

```text
t4 = 20 - 10
```

Resultado:

```text
t4 = 10
```

### Importante

`t3` también viene de una instrucción muy reciente.

---

## Step 11

```asm
sw t4, 0(sp)
```

`sw` guarda un word de 32 bits en memoria.

Dirección efectiva:

```text
sp + 0 = 0
```

Guarda:

```text
MEM[0..3] = 10
```

En hexadecimal:

```text
10 = 0x0000000A
```

Little-endian byte a byte:

| Dirección | Byte   |
| --------- | ------ |
| `MEM[0]`  | `0x0A` |
| `MEM[1]`  | `0x00` |
| `MEM[2]`  | `0x00` |
| `MEM[3]`  | `0x00` |

### Importante

El store usa un dato recién calculado (`t4`). Puede requerir forwarding hacia el dato de store.

---

## Step 12

```asm
lw t5, 0(sp)
```

Lee un word desde memoria:

```text
MEM[0..3] = 10
```

Entonces:

```text
t5 = 10
```

---

# Step 13 — Stall / Bubble

Acá está el punto más importante del TP6.

Las instrucciones son:

```asm
lw    t5, 0(sp)
addi  t6, t5, 1
```

`addi` necesita usar `t5`.

Pero el dato de `lw` aparece tarde, recién luego de MEM.

Entonces el pipeline debe meter:

```text
1 stall / bubble
```

Durante este step no debería cambiar ningún registro arquitectural.

### Qué deberías ver

* PC congelado o IF/ID congelado.
* Bubble entrando a EX.
* `addi t6,t5,1` esperando un ciclo.
* Luego forwarding desde MEM/WB o desde la salida del load.

Si no aparece stall, probablemente `t6` queda mal.

---

## Step 14

```asm
addi t6, t5, 1
```

Después del stall, ya se puede usar `t5`.

Hace:

```text
t6 = 10 + 1
```

Resultado:

```text
t6 = 11
```

---

## Step 15

```asm
add s0, t5, t6
```

Hace:

```text
s0 = 10 + 11
```

Resultado:

```text
s0 = 21
```

### Importante

`t6` viene de la instrucción anterior, así que debe haber forwarding.

---

## Step 16

```asm
sw s0, 4(sp)
```

Guarda:

```text
s0 = 21
```

en memoria:

```text
MEM[4..7] = 21
```

En hexadecimal:

```text
21 = 0x00000015
```

Little-endian:

| Dirección | Byte   |
| --------- | ------ |
| `MEM[4]`  | `0x15` |
| `MEM[5]`  | `0x00` |
| `MEM[6]`  | `0x00` |
| `MEM[7]`  | `0x00` |

---

## Step 17

```asm
lw s1, 4(sp)
```

Lee desde memoria:

```text
MEM[4..7] = 21
```

Entonces:

```text
s1 = 21
```

---

## Step 18

```asm
sub s2, s0, t6
```

Hace:

```text
s2 = 21 - 11
```

Resultado:

```text
s2 = 10
```

---

## Step 19

```asm
addi a0, zero, 1
```

Carga:

```text
a0 = 1
```

Indica que el test llegó correctamente al final.

---

## Step 20

```asm
jal zero, end
```

Salta a `end`.

Como `rd = zero`, no guarda retorno.

El programa queda en loop infinito.

---

# Estado final esperado de registros

| Registro   | Valor decimal | Valor hexadecimal |
| ---------- | ------------: | ----------------- |
| `sp / x2`  |             0 | `0x00000000`      |
| `t0 / x5`  |            10 | `0x0000000A`      |
| `t1 / x6`  |             3 | `0x00000003`      |
| `t2 / x7`  |            13 | `0x0000000D`      |
| `t3 / x28` |            20 | `0x00000014`      |
| `t4 / x29` |            10 | `0x0000000A`      |
| `t5 / x30` |            10 | `0x0000000A`      |
| `t6 / x31` |            11 | `0x0000000B`      |
| `s0 / x8`  |            21 | `0x00000015`      |
| `s1 / x9`  |            21 | `0x00000015`      |
| `s2 / x18` |            10 | `0x0000000A`      |
| `a0 / x10` |             1 | `0x00000001`      |

---

# Estado final esperado de memoria

| Dirección | Byte   |
| --------- | ------ |
| `MEM[0]`  | `0x0A` |
| `MEM[1]`  | `0x00` |
| `MEM[2]`  | `0x00` |
| `MEM[3]`  | `0x00` |
| `MEM[4]`  | `0x15` |
| `MEM[5]`  | `0x00` |
| `MEM[6]`  | `0x00` |
| `MEM[7]`  | `0x00` |

Agrupado:

| Rango       | Valor lógico |
| ----------- | ------------ |
| `MEM[0..3]` | `10`         |
| `MEM[4..7]` | `21`         |

---

# Checks importantes en la debug unit

## 1. Forwarding EX → EX

Revisar:

```asm
add  t2, t0, t1
addi t3, t2, 7
```

`t3` debe quedar en 20.

---

## 2. Forwarding hacia store

Revisar:

```asm
sub t4, t3, t0
sw  t4, 0(sp)
```

`MEM[0..3]` debe quedar en 10.

---

## 3. Load-use stall

Revisar:

```asm
lw    t5, 0(sp)
addi  t6, t5, 1
```

Debe aparecer un stall/bubble.

Si no aparece, `t6` puede quedar mal.

---

## 4. Forwarding después del stall

Luego del stall:

```asm
addi t6, t5, 1
```

debe usar `t5 = 10`.

Resultado:

```text
t6 = 11
```

---

## 5. Store de resultado reciente

```asm
add s0, t5, t6
sw  s0, 4(sp)
```

Debe guardar:

```text
MEM[4..7] = 21
```

---

## 6. `x0 / zero` siempre debe valer 0

Nunca debe modificarse.
