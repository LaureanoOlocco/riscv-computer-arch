# tp7_halt.s — Test de HALT con pipeline drain (15 instrucciones)
# Instrucciones: addi, add, sw, lw, halt
#
# Las ultimas instrucciones antes de HALT escriben a registros y memoria.
# Si el pipeline drain funciona, esas escrituras se completan.
# Si NO funciona, los ultimos registros quedan en 0.

    addi  sp, zero, 0        # sp = 0
    addi  t0, zero, 1        # t0 = 1
    addi  t1, zero, 2        # t1 = 2
    addi  t2, zero, 3        # t2 = 3
    add   t3, t0, t1         # t3 = 3
    add   t4, t2, t3         # t4 = 6
    add   t5, t3, t4         # t5 = 9
    sw    t5, 0(sp)          # MEM[0] = 9
    lw    a0, 0(sp)          # a0 = 9
    addi  a1, a0, 1          # a1 = 10  ← 4 instrs antes del HALT
    addi  a2, a1, 1          # a2 = 11  ← 3 instrs antes
    addi  a3, a2, 1          # a3 = 12  ← 2 instrs antes
    addi  a4, a3, 1          # a4 = 13  ← 2 instrs antes
    add   a5, a4, t0        # a5 = 13 + 1 = 14  ← 1 instr antes
    halt                     # pipeline drain: a1..a5 deben completar WB
