# tp1_arit.s — Aritmetica basica (15 instrucciones)
# Instrucciones: addi, add, sub, lui, auipc, slli, jal

    lui   a0, 1              # a0 = 0x00001000 = 4096
    auipc a1, 0              # a1 = PC = 0x04
    addi  t0, zero, 20       # t0 = 20
    addi  t1, zero, 7        # t1 = 7
    add   t2, t0, t1         # t2 = 27
    sub   t3, t0, t1         # t3 = 13
    add   t4, t2, t3         # t4 = 40
    sub   t5, t2, t3         # t5 = 14
    addi  t6, t4, 10         # t6 = 50
    addi  s0, zero, -3       # s0 = -3 = 0xFFFFFFFD
    add   s1, t0, s0         # s1 = 20 + (-3) = 17
    sub   s2, zero, t1       # s2 = 0 - 7 = -7 = 0xFFFFFFF9
    slli  s3, t1, 3          # s3 = 7 << 3 = 56
    addi  a2, zero, 1        # a2 = 1 (OK)
end:
    jal   zero, end
