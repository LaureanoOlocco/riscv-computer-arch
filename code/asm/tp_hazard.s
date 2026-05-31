# ---------------------------------------------------------------
# tp_hazard.s — Hazards de datos y forwarding
#
# Fuerza todos los caminos de forwarding del pipeline:
#   - EX→EX (resultado R-type usado inmediatamente)
#   - MEM→EX (resultado de 2 instrucciones atras)
#   - Load-use (lw seguido de uso inmediato → stall + forward)
#   - Store con forwarding (sw con dato recien calculado)
#
# Calcula el factorial de 5 iterativamente: 5! = 120,
# con dependencias de datos consecutivas en cada paso.
#
# Instrucciones ejercitadas:
#   addi, add, sub, mul (simulado con adds)
#   sw, lw
#   beq, bne, bge
#
# Registros esperados al final:
#   t0 = 120      (5! = 120)
#   t1 = 0        (contador llego a 0)
#   t2 = 120      (copia del resultado)
#   t3 = 121      (t2 + 1 = 121, forwarding EX→EX)
#   t4 = 241      (t2 + t3 = 120 + 121 = 241, forwarding doble)
#   t5 = 120      (releido desde DMEM, load-use test)
#   t6 = 121      (t5 + 1, usa t5 inmediatamente — load-use hazard)
#   s0 = 242      (t5 + t6 = 120 + 122... no: t6=121, 120+121=241)
#   a0 = 1        (flag OK)
#
# Nota: s0 = t5 + t6 = 120 + 121 = 241
# ---------------------------------------------------------------

    addi  sp, zero, 0

    # --- Factorial iterativo: t0 = 5! ---
    addi  t0, zero, 1        # t0 = acumulador = 1
    addi  t1, zero, 5        # t1 = contador = 5

fact_loop:
    beq   t1, zero, fact_done

    # Multiplicar t0 por t1 usando sumas sucesivas
    add   a5, zero, t0       # a5 = t0 (valor a sumar t1 veces)
    addi  a6, zero, 1        # a6 = contador de sumas (empezar en 1, ya tenemos t0)

mul_loop:
    beq   a6, t1, mul_done
    add   t0, t0, a5         # t0 += a5 (forwarding EX→EX en cada iteracion)
    addi  a6, a6, 1          # a6++ (forwarding EX→EX)
    jal   zero, mul_loop

mul_done:
    addi  t1, t1, -1         # t1-- (forwarding MEM→EX: t1 de 2 instrs atras)
    jal   zero, fact_loop

fact_done:
    # t0 = 120 (5! = 5*4*3*2*1)

    # --- Cadena de forwarding EX→EX ---
    add   t2, zero, t0       # t2 = 120 (forward t0)
    addi  t3, t2, 1          # t3 = 121 (forward t2, EX→EX)
    add   t4, t2, t3         # t4 = 241 (forward t2 y t3)

    # --- Store + load-use hazard ---
    sw    t0, 0(sp)           # MEM[0] = 120
    lw    t5, 0(sp)           # t5 = 120 (load)
    addi  t6, t5, 1          # t6 = 121 (load-use: usa t5 inmediatamente)
    add   s0, t5, t6         # s0 = 120 + 121 = 241 (forwarding desde load y EX)

    # --- Store con dato recien calculado (forwarding a store data) ---
    sw    s0, 4(sp)           # MEM[4] = 241 (s0 recien calculado)
    lw    s1, 4(sp)           # s1 = 241 (verificar store)

    # --- Flag OK ---
    addi  a0, zero, 1

end:
    jal   zero, end
