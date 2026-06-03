# TP5 — Jumps, funciones y branches unsigned: registros esperados step por step

Archivo: `tp5_jumps.s`

## Suposiciones

* Pipeline de 5 etapas: IF, ID, EX, MEM, WB.
* 1 step = 1 ciclo de clock.
* Los registros cambian cuando la instrucción llega a WB.
* Los stores cambian memoria en MEM.
* Los jumps/branches pueden generar flush.
* Todos los registros empiezan en 0.
* `x0 / zero` siempre vale 0.

---

# Objetivo del TP5

Este test valida:

* `jal`
* `jalr`
* llamadas a función
* retorno usando `ra`
* stack usando `sp`
* branches unsigned: `bltu`, `bgeu`
* cambio de PC
* flush del pipeline

---

# IMPORTANTE SOBRE LOS STEPS

Como TP5 usa `jal`, `jalr`, `bltu` y `bgeu`, el número exacto de ciclos puede variar según tu core:

* en qué etapa resuelve jumps,
* cuántos stages flushea,
* si la debug unit cuenta bubbles,
* si el jump se resuelve en ID o EX.

Por eso esta tabla muestra el **orden arquitectural esperado**, es decir, las instrucciones que sí deben tener efecto.

---

# Código relevante

```asm
addi  sp, zero, 32
addi  a0, zero, 5
jal   ra, fn_doble

add   a1, zero, a0
addi  t0, zero, 3
addi  t1, zero, 20

bltu  t0, t1, u_ok
addi  a2, zero, -1

u_ok:
bgeu  t1, t0, u2_ok
addi  a2, zero, -1

u2_ok:
addi  a2, zero, 1
jal   zero, end

fn_doble:
addi  sp, sp, -4
sw    ra, 0(sp)
add   a0, a0, a0
lw    ra, 0(sp)
addi  sp, sp, 4
jalr  zero, ra, 0

end:
jal   zero, end
```

---

# Tabla step por step arquitectural

| Step lógico | Instrucción que completa | Cambia        | Valor esperado       | Qué significa                       |
| ----------- | ------------------------ | ------------- | -------------------- | ----------------------------------- |
| 1–4         | -                        | nada          | -                    | Pipeline llenándose                 |
| 5           | `addi sp, zero, 32`      | `sp / x2`     | `32`                 | Inicializa stack pointer            |
| 6           | `addi a0, zero, 5`       | `a0 / x10`    | `5`                  | Argumento de la función             |
| 7           | `jal ra, fn_doble`       | `ra / x1`, PC | `ra = PC + 4`        | Salta a la función y guarda retorno |
| 8           | `addi sp, sp, -4`        | `sp / x2`     | `28`                 | Reserva espacio en stack            |
| 9           | `sw ra, 0(sp)`           | `MEM[28..31]` | `ra`                 | Guarda dirección de retorno         |
| 10          | `add a0, a0, a0`         | `a0 / x10`    | `10`                 | Duplica argumento                   |
| 11          | `lw ra, 0(sp)`           | `ra / x1`     | dirección de retorno | Recupera `ra`                       |
| 12          | `addi sp, sp, 4`         | `sp / x2`     | `32`                 | Libera stack                        |
| 13          | `jalr zero, ra, 0`       | PC            | `ra`                 | Vuelve de la función                |
| 14          | `add a1, zero, a0`       | `a1 / x11`    | `10`                 | Copia resultado de función          |
| 15          | `addi t0, zero, 3`       | `t0 / x5`     | `3`                  | Carga 3                             |
| 16          | `addi t1, zero, 20`      | `t1 / x6`     | `20`                 | Carga 20                            |
| 17          | `bltu t0, t1, u_ok`      | PC            | target `u_ok`        | Branch unsigned tomado              |
| 18          | `bgeu t1, t0, u2_ok`     | PC            | target `u2_ok`       | Branch unsigned tomado              |
| 19          | `addi a2, zero, 1`       | `a2 / x12`    | `1`                  | Test OK                             |
| 20          | `jal zero, end`          | PC            | `end`                | Salta al loop final                 |
| 21          | `jal zero, end`          | PC            | `end`                | Loop infinito                       |

---

# Detalle de cada instrucción

## Step 5

```asm
addi sp, zero, 32
```

Hace:

```text
sp = 0 + 32
```

Resultado:

```text
sp = 32
```

`sp` es el stack pointer. En este TP se usa como base para guardar `ra`.

---

## Step 6

```asm
addi a0, zero, 5
```

Hace:

```text
a0 = 5
```

`a0` se usa como argumento de la función `fn_doble`.

---

## Step 7

```asm
jal ra, fn_doble
```

`jal` significa Jump And Link.

Hace dos cosas:

```text
ra = PC + 4
PC = fn_doble
```

Entonces:

* guarda en `ra` la dirección de retorno,
* salta a la función `fn_doble`.

Después de esta instrucción, el flujo NO sigue linealmente con `add a1, zero, a0`; primero entra a la función.

---

## Step 8

```asm
addi sp, sp, -4
```

Dentro de la función.

Hace:

```text
sp = 32 - 4
```

Resultado:

```text
sp = 28
```

Esto reserva 4 bytes en el stack.

---

## Step 9

```asm
sw ra, 0(sp)
```

`sw` guarda un word de 32 bits en memoria.

La dirección efectiva es:

```text
sp + 0 = 28
```

Entonces:

```text
MEM[28..31] = ra
```

Esto guarda temporalmente la dirección de retorno.

---

## Step 10

```asm
add a0, a0, a0
```

Hace:

```text
a0 = 5 + 5
```

Resultado:

```text
a0 = 10
```

Esta es la operación principal de la función: duplicar el argumento.

---

## Step 11

```asm
lw ra, 0(sp)
```

`lw` lee un word desde memoria.

Dirección:

```text
sp + 0 = 28
```

Entonces recupera:

```text
ra = MEM[28..31]
```

Es decir, recupera la dirección de retorno.

---

## Step 12

```asm
addi sp, sp, 4
```

Libera el espacio reservado en el stack.

Hace:

```text
sp = 28 + 4
```

Resultado:

```text
sp = 32
```

El stack vuelve a su valor original.

---

## Step 13

```asm
jalr zero, ra, 0
```

`jalr` significa Jump And Link Register.

Hace:

```text
PC = ra + 0
```

Como `rd = zero`, no guarda retorno.

Esta instrucción funciona como un `return`.

El programa vuelve a la instrucción después del `jal` inicial:

```asm
add a1, zero, a0
```

---

## Step 14

```asm
add a1, zero, a0
```

Hace:

```text
a1 = 0 + a0
```

Como la función dejó:

```text
a0 = 10
```

entonces:

```text
a1 = 10
```

Esto copia el resultado de la función.

---

## Step 15

```asm
addi t0, zero, 3
```

Carga:

```text
t0 = 3
```

---

## Step 16

```asm
addi t1, zero, 20
```

Carga:

```text
t1 = 20
```

---

## Step 17

```asm
bltu t0, t1, u_ok
```

`bltu` significa:

```text
Branch if Less Than Unsigned
```

Compara unsigned:

```text
3 <u 20
```

Eso es verdadero.

Entonces:

```text
PC = u_ok
```

La instrucción siguiente:

```asm
addi a2, zero, -1
```

NO debe ejecutarse.

Si `a2` llega a valer `0xFFFFFFFF`, hay un bug de branch/flush.

---

## Step 18

```asm
bgeu t1, t0, u2_ok
```

`bgeu` significa:

```text
Branch if Greater or Equal Unsigned
```

Compara:

```text
20 >=u 3
```

Eso es verdadero.

Entonces:

```text
PC = u2_ok
```

La instrucción siguiente:

```asm
addi a2, zero, -1
```

NO debe ejecutarse.

---

## Step 19

```asm
addi a2, zero, 1
```

Hace:

```text
a2 = 1
```

Esto indica que los branches unsigned funcionaron correctamente.

---

## Step 20

```asm
jal zero, end
```

Salta a `end`.

Como `rd = zero`, no guarda retorno.

---

## Step 21

```asm
jal zero, end
```

Loop infinito.

No cambia registros.

---

# Estado final esperado de registros

| Registro   |              Valor decimal | Valor hexadecimal  |
| ---------- | -------------------------: | ------------------ |
| `ra / x1`  | dirección después de `jal` | depende del layout |
| `sp / x2`  |                         32 | `0x00000020`       |
| `a0 / x10` |                         10 | `0x0000000A`       |
| `a1 / x11` |                         10 | `0x0000000A`       |
| `a2 / x12` |                          1 | `0x00000001`       |
| `t0 / x5`  |                          3 | `0x00000003`       |
| `t1 / x6`  |                         20 | `0x00000014`       |

---

# Estado esperado de memoria

Durante la función:

| Dirección     | Valor |
| ------------- | ----- |
| `MEM[28..31]` | `ra`  |

Al final, esa memoria puede seguir conteniendo `ra`. Lo importante es que:

```text
sp = 32
```

porque el stack fue restaurado.

---

# Checks importantes en la debug unit

## 1. Revisar `jal`

Después de:

```asm
jal ra, fn_doble
```

deberías ver:

```text
ra = PC + 4
PC = fn_doble
```

---

## 2. Revisar `sp`

Debe hacer:

```text
32 → 28 → 32
```

Si queda en 28, la función no restauró bien el stack.

---

## 3. Revisar memoria

Después de:

```asm
sw ra, 0(sp)
```

debería aparecer:

```text
MEM[28..31] = ra
```

---

## 4. Revisar `jalr`

Después de:

```asm
jalr zero, ra, 0
```

el PC debe volver a la instrucción:

```asm
add a1, zero, a0
```

---

## 5. Revisar resultado de función

Después del return:

```text
a0 = 10
a1 = 10
```

---

## 6. Revisar branches unsigned

Estas instrucciones deben saltar:

```asm
bltu t0, t1, u_ok
bgeu t1, t0, u2_ok
```

Las instrucciones:

```asm
addi a2, zero, -1
```

NO deben modificar `a2`.

---

## 7. `x0 / zero` siempre debe valer 0

Nunca debe cambiar.
