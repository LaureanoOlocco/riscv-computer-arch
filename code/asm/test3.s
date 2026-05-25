# ---------------------------------------------------------------
# test3.s — Sin hazards: cada instruccion tarda exactamente 5 ciclos
# Se insertan NOP (addi zero,zero,0) para evitar load-use,
# branch-data y flush penalties.
# ---------------------------------------------------------------

    # ---- 1. LUI ----
    lui   a0, 1             # a0 = 0x00001000

    # ---- 2. AUIPC ----
    auipc a1, 0             # a1 = PC de esta instr = 0x00000008

    # ---- 3. ADDI t0 = 1 ----
    addi  t0, zero, 1       # t0 = 1

    # ---- 4. SLL: necesita t0 listo — viene de instr anterior, forwarding OK ----
    sll   t1, t0, t0        # t1 = 2

    # ---- 5. SLLI ----
    slli  t2, t0, 4         # t2 = 16

    # ---- 6. ADDI t3 = -1 ----
    addi  t3, zero, -1      # t3 = 0xFFFFFFFF

    # ---- 7. SRL: t3 de 2 instrs atras, forwarding OK ----
    srl   t4, t3, t0        # t4 = 0x7FFFFFFF

    # ---- 8. SRA ----
    sra   t5, t3, t0        # t5 = 0xFFFFFFFF

    # ---- 9. SRLI ----
    srli  t6, t3, 4         # t6 = 0x0FFFFFFF

    # ---- 10. SRAI ----
    srai  s0, t3, 4         # s0 = 0xFFFFFFFF

    # ---- 11. SLT setup ----
    addi  s1, zero, 5       # s1 = 5
    addi  s2, zero, 10      # s2 = 10

    # ---- 12. SLT ----
    slt   s3, s1, s2        # s3 = 1

    # ---- 13. SLT inverso ----
    slt   s4, s2, s1        # s4 = 0

    # ---- 14. SLTU ----
    sltu  s5, t0, s2        # s5 = 1

    # ---- 15. SLTI ----
    slti  s6, s1, 3         # s6 = 0

    # ---- 16. SLTIU ----
    sltiu s7, t0, 100       # s7 = 1

    # ---- 17. XORI ----
    addi  a2, zero, 15      # a2 = 0x0F
    xori  a3, a2, 255       # a3 = 0xFFFFFFF0

    # ---- 18. ANDI ----
    andi  a4, a2, 3         # a4 = 0x03

    # ---- 19. ORI ----
    ori   a5, a2, 112       # a5 = 0x7F

    # ---- 20. SB + LB/LBU: nop entre store y load para evitar hazard ----
    addi  sp, zero, 0
    addi  t0, zero, 171     # t0 = 0xAB
    sb    t0, 0(sp)
    addi  zero, zero, 0     # nop
    addi  zero, zero, 0     # nop
    lb    a6, 0(sp)         # a6 = 0xFFFFFFAB
    addi  zero, zero, 0     # nop (load-use: a6 no se usa inmediatamente)
    lbu   a7, 0(sp)         # a7 = 0x000000AB

    # ---- 21. SH + LH/LHU ----
    addi  t0, zero, 18      # t0 = 0x12
    sh    t0, 2(sp)
    addi  zero, zero, 0     # nop
    addi  zero, zero, 0     # nop
    lh    s8, 2(sp)         # s8 = 0x00000012
    addi  zero, zero, 0     # nop
    lhu   s9, 2(sp)         # s9 = 0x00000012

    # ---- 22. Load-use con nop en medio ----
    addi  t0, zero, 42
    sw    t0, 8(sp)
    addi  zero, zero, 0     # nop
    addi  zero, zero, 0     # nop
    lw    t1, 8(sp)         # t1 = 42
    addi  zero, zero, 0     # nop (evita load-use con t2)
    addi  t2, t1, 1         # t2 = 43
    add   t3, t1, t2        # t3 = 85

    # ---- 23. BEQ tomado: 2 nop post-branch para absorber flush ----
    addi  t0, zero, 7
    addi  t1, zero, 7
    beq   t0, t1, beq_ok
    addi  zero, zero, 0     # flush slot 1
    addi  zero, zero, 0     # flush slot 2
beq_ok:
    # ---- 24. BNE no tomado: sin flush ----
    bne   t0, t1, end

    # ---- 25. BLT tomado ----
    addi  t1, zero, 3
    blt   t1, t0, blt_ok
    addi  zero, zero, 0
    addi  zero, zero, 0
blt_ok:
    # ---- 26. BGEU tomado ----
    addi  t2, zero, 10
    bgeu  t2, t0, bgeu_ok
    addi  zero, zero, 0
    addi  zero, zero, 0
bgeu_ok:
    # ---- 27. BLTU tomado ----
    bltu  t1, t2, bltu_ok
    addi  zero, zero, 0
    addi  zero, zero, 0
bltu_ok:
    # ---- 28. JAL + JALR (call/return) ----
    addi  ra, zero, 0
    jal   ra, myfunc
    addi  zero, zero, 0     # flush slot 1
    addi  zero, zero, 0     # flush slot 2
after_call:
    addi  a0, zero, 1       # a0 = 1 (OK)
    jal   zero, end
    addi  zero, zero, 0
    addi  zero, zero, 0

myfunc:
    addi  a1, zero, 99      # a1 = 99
    jalr  zero, ra, 0       # return
    addi  zero, zero, 0
    addi  zero, zero, 0

end:
    jal   zero, end
