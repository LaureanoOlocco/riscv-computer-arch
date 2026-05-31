# tp4_cmp.s — Comparaciones y branches (18 instrucciones)
# Instrucciones: slt, sltu, slti, sltiu, beq, bne, blt, bge, addi, jal

    addi  t0, zero, 10       # t0 = 10
    addi  t1, zero, -5       # t1 = -5 = 0xFFFFFFFB
    slt   a0, t1, t0         # a0 = 1 (-5 < 10, signed)
    slt   a1, t0, t1         # a1 = 0 (10 < -5? no)
    sltu  a2, t0, t1         # a2 = 1 (10 <u 0xFFFFFFFB, unsigned: si)
    slti  a3, t0, 15         # a3 = 1 (10 < 15)
    sltiu a4, t0, 5          # a4 = 0 (10 <u 5? no)
    beq   t0, t0, eq_ok      # debe saltar (10 == 10)
    addi  a5, zero, -1       # NO ejecutar
eq_ok:
    addi  a5, zero, 1        # a5 = 1 (beq funciono)
    bne   t0, t1, ne_ok      # debe saltar (10 != -5)
    addi  a5, zero, -1       # NO ejecutar
ne_ok:
    blt   t1, t0, lt_ok      # debe saltar (-5 < 10)
    addi  a5, zero, -1       # NO ejecutar
lt_ok:
    bge   t0, t1, ge_ok      # debe saltar (10 >= -5)
    addi  a5, zero, -1       # NO ejecutar
ge_ok:
    addi  a5, zero, 7        # a5 = 7 (todos los branches OK)
end:
    jal   zero, end
