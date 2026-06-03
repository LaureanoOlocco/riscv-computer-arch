# TP4 — Comparaciones y branches: registros esperados step por step

## Suposiciones

* Pipeline de 5 etapas: IF, ID, EX, MEM, WB.
* 1 step = 1 ciclo de clock.
* Los registros cambian cuando la instrucción llega a WB.
* Los branches cambian el PC cuando se resuelven.
* Si un branch es tomado, las instrucciones del camino incorrecto deben ser anuladas con flush.
* Todos los registros empiezan en 0.
* `x0 / zero` siempre vale 0.

---

# Objetivo del TP4

Este test valida:

* Comparaciones signed
* Comparaciones unsigned
* Branches condicionales
* Flush del pipeline
* Control hazards
* Cálculo correcto del PC destino

---

# Instrucciones nuevas importantes

| Instrucción | Significado                       |
| ----------- | --------------------------------- |
| `slt`       | set less than signed              |
| `sltu`      | set less than unsigned            |
| `slti`      | set less than immediate signed    |
| `sltiu`     | set less than immediate unsigned  |
| `beq`       | branch if equal                   |
| `bne`       | branch if not equal               |
| `blt`       | branch if less than signed        |
| `bge`       | branch if greater or equal signed |

---

# Tabla lógica del programa

| Instrucción       | Resultado esperado                 |
| ----------------- | ---------------------------------- |
| `t0 = 10`         | carga positivo                     |
| `t1 = -5`         | carga negativo                     |
| `slt a0,t1,t0`    | `a0 = 1` porque `-5 < 10`          |
| `slt a1,t0,t1`    | `a1 = 0` porque `10 < -5` es falso |
| `sltu a2,t0,t1`   | `a2 = 1` porque `10 <u 0xFFFFFFFB` |
| `slti a3,t0,15`   | `a3 = 1` porque `10 < 15`          |
| `sltiu a4,t0,5`   | `a4 = 0` porque `10 <u 5` es falso |
| `beq t0,t0,eq_ok` | branch tomado                      |
| `bne t0,t1,ne_ok` | branch tomado                      |
| `blt t1,t0,lt_ok` | branch tomado                      |
| `bge t0,t1,ge_ok` | branch tomado                      |
| `addi a5,zero,7`  | valor final de `a5`                |

---

# IMPORTANTE SOBRE LOS STEPS

Como este TP tiene branches tomados, el número exacto de steps puede variar según:

* en qué etapa tu core resuelve el branch,
* cuántos stages flushea,
* si la debug unit cuenta bubbles como steps,
* si el PC se redirige en EX o antes.

Por eso acá se muestra el orden arquitectural esperado, es decir, las instrucciones que sí deben tener efecto.

Las instrucciones:

```asm
addi a5, zero, -1
```

después de cada branch **NO deben cambiar `a5`**.

Si alguna vez ves:

```text
a5 = 0xFFFFFFFF
```

el flush del branch falló.

---

# Tabla step por step arquitectural

| Step lógico | Instrucción que completa | Cambia     | Valor esperado    | Qué significa             |
| ----------- | ------------------------ | ---------- | ----------------- | ------------------------- |
| 1–4         | -                        | nada       | -                 | Pipeline llenándose       |
| 5           | `addi t0, zero, 10`      | `t0 / x5`  | `0x0000000A` = 10 | Carga 10                  |
| 6           | `addi t1, zero, -5`      | `t1 / x6`  | `0xFFFFFFFB` = -5 | Carga negativo            |
| 7           | `slt a0, t1, t0`         | `a0 / x10` | `1`               | `-5 < 10` signed          |
| 8           | `slt a1, t0, t1`         | `a1 / x11` | `0`               | `10 < -5` signed es falso |
| 9           | `sltu a2, t0, t1`        | `a2 / x12` | `1`               | `10 <u 0xFFFFFFFB`        |
| 10          | `slti a3, t0, 15`        | `a3 / x13` | `1`               | `10 < 15` signed          |
| 11          | `sltiu a4, t0, 5`        | `a4 / x14` | `0`               | `10 <u 5` es falso        |
| 12          | `beq t0, t0, eq_ok`      | PC         | target `eq_ok`    | Branch tomado             |
| 13          | `addi a5, zero, 1`       | `a5 / x15` | `1`               | Llegó a `eq_ok`           |
| 14          | `bne t0, t1, ne_ok`      | PC         | target `ne_ok`    | Branch tomado             |
| 15          | `blt t1, t0, lt_ok`      | PC         | target `lt_ok`    | Branch tomado             |
| 16          | `bge t0, t1, ge_ok`      | PC         | target `ge_ok`    | Branch tomado             |
| 17          | `addi a5, zero, 7`       | `a5 / x15` | `7`               | Todos los branches OK     |
| 18          | `jal zero, end`          | PC         | `end`             | Loop infinito             |

---

# Detalle de cada instrucción

## Step 5

```asm
addi t0, zero, 10
```

Hace:

```text
t0 = 0 + 10
```

Resultado:

```text
t0 = 10
```

---

## Step 6

```asm
addi t1, zero, -5
```

Carga `-5`.

En complemento a 2:

```text
t1 = 0xFFFFFFFB
```

Este valor puede interpretarse de dos formas:

| Interpretación | Valor      |
| -------------- | ---------- |
| signed         | -5         |
| unsigned       | 4294967291 |

---

## Step 7

```asm
slt a0, t1, t0
```

`slt` significa:

```text
Set Less Than
```

Comparación signed:

```text
a0 = (t1 < t0) ? 1 : 0
```

Como:

```text
-5 < 10
```

es verdadero:

```text
a0 = 1
```

---

## Step 8

```asm
slt a1, t0, t1
```

Comparación signed:

```text
a1 = (10 < -5) ? 1 : 0
```

Eso es falso:

```text
a1 = 0
```

---

## Step 9

```asm
sltu a2, t0, t1
```

`sltu` compara unsigned.

Entonces no ve `t1` como `-5`, sino como:

```text
0xFFFFFFFB = 4294967291
```

Comparación:

```text
10 < 4294967291
```

Es verdadero:

```text
a2 = 1
```

---

## Step 10

```asm
slti a3, t0, 15
```

`slti` compara signed contra un inmediato:

```text
a3 = (10 < 15) ? 1 : 0
```

Resultado:

```text
a3 = 1
```

---

## Step 11

```asm
sltiu a4, t0, 5
```

`sltiu` compara unsigned contra un inmediato:

```text
a4 = (10 <u 5) ? 1 : 0
```

Es falso:

```text
a4 = 0
```

---

# Branches y flush

A partir de acá las instrucciones ya no son lineales.

Cada branch tomado debe saltar sobre una instrucción mala:

```asm
addi a5, zero, -1
```

Esa instrucción está puesta a propósito para detectar errores.

Si se ejecuta, el branch o el flush están mal.

---

## Step 12

```asm
beq t0, t0, eq_ok
```

`beq` significa:

```text
Branch if Equal
```

Condición:

```text
t0 == t0
10 == 10
```

Verdadero.

Entonces:

```text
PC = eq_ok
```

La instrucción siguiente:

```asm
addi a5, zero, -1
```

NO debe escribir `a5`.

---

## Step 13

```asm
addi a5, zero, 1
```

Esta es la primera instrucción correcta después del branch.

Resultado:

```text
a5 = 1
```

---

## Step 14

```asm
bne t0, t1, ne_ok
```

`bne` significa:

```text
Branch if Not Equal
```

Condición:

```text
10 != -5
```

Verdadero.

Entonces:

```text
PC = ne_ok
```

La siguiente instrucción mala:

```asm
addi a5, zero, -1
```

NO debe ejecutarse.

---

## Step 15

```asm
blt t1, t0, lt_ok
```

`blt` significa:

```text
Branch if Less Than
```

Comparación signed:

```text
-5 < 10
```

Verdadero.

Entonces:

```text
PC = lt_ok
```

La siguiente instrucción mala:

```asm
addi a5, zero, -1
```

NO debe ejecutarse.

---

## Step 16

```asm
bge t0, t1, ge_ok
```

`bge` significa:

```text
Branch if Greater or Equal
```

Comparación signed:

```text
10 >= -5
```

Verdadero.

Entonces:

```text
PC = ge_ok
```

La siguiente instrucción mala:

```asm
addi a5, zero, -1
```

NO debe ejecutarse.

---

## Step 17

```asm
addi a5, zero, 7
```

Si todos los branches anteriores funcionaron bien, recién acá `a5` queda con valor final:

```text
a5 = 7
```

---

## Step 18

```asm
jal zero, end
```

Salta a `end`.

Como `rd = zero`, no guarda retorno.

El programa queda en loop infinito.

---

# Estado final esperado

| Registro   | Valor decimal | Valor hexadecimal |
| ---------- | ------------: | ----------------- |
| `t0 / x5`  |            10 | `0x0000000A`      |
| `t1 / x6`  |            -5 | `0xFFFFFFFB`      |
| `a0 / x10` |             1 | `0x00000001`      |
| `a1 / x11` |             0 | `0x00000000`      |
| `a2 / x12` |             1 | `0x00000001`      |
| `a3 / x13` |             1 | `0x00000001`      |
| `a4 / x14` |             0 | `0x00000000`      |
| `a5 / x15` |             7 | `0x00000007`      |

---

# Checks importantes en la debug unit

## 1. `a5` nunca debería quedar en -1

Cada instrucción:

```asm
addi a5, zero, -1
```

está en el camino incorrecto.

Si alguna llega a WB:

```text
a5 = 0xFFFFFFFF
```

hay un bug de branch/flush.

---

## 2. Revisar signed vs unsigned

Especialmente:

```asm
slt a1, t0, t1
sltu a2, t0, t1
```

Deben dar distinto:

```text
a1 = 0
a2 = 1
```

---

## 3. Revisar PC

El PC no debe avanzar siempre +4.

Debe saltar a:

```text
eq_ok
ne_ok
lt_ok
ge_ok
end
```

---

## 4. Revisar flush

Después de cada branch tomado, las instrucciones ya fetcheadas del camino incorrecto deben anularse.

---

## 5. x0 siempre debe valer 0

Nunca debe modificarse.
