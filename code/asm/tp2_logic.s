# tp2_logic.s — Logica y shifts (16 instrucciones)
# Instrucciones: and, or, xor, andi, ori, xori, sll, srl, sra, srli, srai, addi, jal

    addi  t0, zero, 0x0F     # t0 = 0x0F = 15
    addi  t1, zero, 0x36     # t1 = 0x36 = 54
    and   t2, t0, t1         # t2 = 0x06 = 6
    or    t3, t0, t1         # t3 = 0x3F = 63
    xor   t4, t0, t1         # t4 = 0x39 = 57
    andi  t5, t1, 0x0F       # t5 = 0x06 = 6
    ori   t6, t0, 0x30       # t6 = 0x3F = 63
    xori  s0, t0, 0xFF       # s0 = 0xFFFFFFF0 (sign-ext 0xFF, xor con 0x0F)
    addi  s1, zero, -1       # s1 = 0xFFFFFFFF
    addi  s2, zero, 2        # s2 = 2
    sll   s3, t0, s2         # s3 = 15 << 2 = 60
    srl   s4, s1, s2         # s4 = 0x3FFFFFFF
    sra   s5, s1, s2         # s5 = 0xFFFFFFFF (aritmetico, mantiene signo)
    srli  s6, s1, 16         # s6 = 0x0000FFFF = 65535
    srai  s7, s1, 16         # s7 = 0xFFFFFFFF (aritmetico)
end:
    jal   zero, end
