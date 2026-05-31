# tp6_hazard.s — Hazards de datos y forwarding (15 instrucciones)
# Instrucciones: addi, add, sub, sw, lw, jal
# Fuerza: EX->EX forwarding, MEM->EX forwarding, load-use stall

    addi  sp, zero, 0        # sp = 0
    addi  t0, zero, 10       # t0 = 10
    addi  t1, zero, 3        # t1 = 3
    add   t2, t0, t1         # t2 = 13 (fwd t0 desde EX, t1 desde EX)
    addi  t3, t2, 7          # t3 = 20 (fwd t2 desde EX, cadena EX->EX)
    sub   t4, t3, t0         # t4 = 10 (fwd t3 EX->EX, t0 desde MEM)
    sw    t4, 0(sp)          # MEM[0] = 10
    lw    t5, 0(sp)          # t5 = 10 (load)
    addi  t6, t5, 1          # t6 = 11 (load-use hazard: stall + forward)
    add   s0, t5, t6         # s0 = 21 (fwd load + fwd EX)
    sw    s0, 4(sp)          # MEM[4] = 21 (store con dato recien calculado)
    lw    s1, 4(sp)          # s1 = 21 (verifica store)
    sub   s2, s0, t6         # s2 = 21 - 11 = 10 (fwd multiples fuentes)
    addi  a0, zero, 1        # a0 = 1 (OK)
end:
    jal   zero, end
