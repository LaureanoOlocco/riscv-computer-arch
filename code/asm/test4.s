# test4.s — Sin hazards, branches con suficientes NOPs para garantizar WB antes del branch

    # ---- 1. LUI ----
    lui   a0, 1

    # ---- 2. AUIPC ----
    auipc a1, 0

    # ---- 3-10. Shifts y aritmetica ----
    addi  t0, zero, 1
    sll   t1, t0, t0
    slli  t2, t0, 4
    addi  t3, zero, -1
    srl   t4, t3, t0
    sra   t5, t3, t0
    srli  t6, t3, 4
    srai  s0, t3, 4

    # ---- 11-17. SLT / comparaciones ----
    addi  s1, zero, 5
    addi  s2, zero, 10
    slt   s3, s1, s2
    slt   s4, s2, s1
    sltu  s5, t0, s2
    slti  s6, s1, 3
    sltiu s7, t0, 100

    # ---- 18-21. Logica inmediata ----
    addi  a2, zero, 15
    xori  a3, a2, 255
    andi  a4, a2, 3
    ori   a5, a2, 112

    # ---- 22-30. Memoria ----
    addi  sp, zero, 0
    addi  t0, zero, 171
    sb    t0, 0(sp)
    addi  zero, zero, 0
    addi  zero, zero, 0
    lb    a6, 0(sp)
    addi  zero, zero, 0
    lbu   a7, 0(sp)
    addi  t0, zero, 18
    sh    t0, 2(sp)
    addi  zero, zero, 0
    addi  zero, zero, 0
    lh    s8, 2(sp)
    addi  zero, zero, 0
    lhu   s9, 2(sp)
    addi  t0, zero, 42
    sw    t0, 8(sp)
    addi  zero, zero, 0
    addi  zero, zero, 0
    lw    t1, 8(sp)
    addi  zero, zero, 0
    addi  t2, t1, 1
    add   t3, t1, t2

    # ---- 31. BEQ tomado ----
    # t0=7, t1=7 — ponemos 4 NOPs antes del branch para garantizar WB
    addi  t0, zero, 7
    addi  zero, zero, 0
    addi  zero, zero, 0
    addi  zero, zero, 0
    addi  t1, zero, 7
    addi  zero, zero, 0
    addi  zero, zero, 0
    addi  zero, zero, 0
    beq   t0, t1, beq_ok
    addi  zero, zero, 0
    addi  zero, zero, 0
beq_ok:

    # ---- 32. BNE no tomado ----
    bne   t0, t1, end
    addi  zero, zero, 0
    addi  zero, zero, 0

    # ---- 33. BLT tomado ----
    addi  t1, zero, 3
    addi  zero, zero, 0
    addi  zero, zero, 0
    addi  zero, zero, 0
    blt   t1, t0, blt_ok
    addi  zero, zero, 0
    addi  zero, zero, 0
blt_ok:

    # ---- 34. BGEU tomado ----
    addi  t2, zero, 10
    addi  zero, zero, 0
    addi  zero, zero, 0
    addi  zero, zero, 0
    bgeu  t2, t0, bgeu_ok
    addi  zero, zero, 0
    addi  zero, zero, 0
bgeu_ok:

    # ---- 35. BLTU tomado ----
    bltu  t1, t2, bltu_ok
    addi  zero, zero, 0
    addi  zero, zero, 0
bltu_ok:

    # ---- 36. JAL + JALR ----
    addi  ra, zero, 0
    addi  zero, zero, 0
    addi  zero, zero, 0
    addi  zero, zero, 0
    jal   ra, myfunc
    addi  zero, zero, 0
    addi  zero, zero, 0
after_call:
    addi  a0, zero, 1
    jal   zero, end
    addi  zero, zero, 0
    addi  zero, zero, 0

myfunc:
    addi  a1, zero, 99
    jalr  zero, ra, 0
    addi  zero, zero, 0
    addi  zero, zero, 0

end:
    jal   zero, end
