# tp3_mem.s — Accesos a memoria (17 instrucciones)
# Instrucciones: sw, lw, sb, lb, lbu, sh, lh, lhu, addi, jal

    addi  sp, zero, 0        # sp = 0 (base DMEM)
    addi  t0, zero, 0x41     # t0 = 0x41 = 65 ('A')
    addi  t1, zero, -100     # t1 = 0xFFFFFF9C = -100
    sw    t1, 0(sp)          # MEM[0..3] = 0xFFFFFF9C
    lw    a0, 0(sp)          # a0 = 0xFFFFFF9C = -100
    sb    t0, 4(sp)          # MEM[4] = 0x41
    addi  t2, zero, -1       # t2 = 0xFF (como byte)
    sb    t2, 5(sp)          # MEM[5] = 0xFF
    lb    a1, 4(sp)          # a1 = 0x00000041 = 65 (sign-ext, positivo)
    lbu   a2, 5(sp)          # a2 = 0x000000FF = 255 (zero-ext)
    lb    a3, 5(sp)          # a3 = 0xFFFFFFFF = -1 (sign-ext 0xFF)
    addi  t3, zero, 0x7FF    # t3 = 2047
    sh    t3, 8(sp)          # MEM[8..9] = 0x07FF
    lh    a4, 8(sp)          # a4 = 0x000007FF = 2047 (sign-ext, positivo)
    lhu   a5, 8(sp)          # a5 = 0x000007FF = 2047 (zero-ext, igual)
    lbu   a6, 0(sp)          # a6 = 0x9C = 156 (LSB de -100, zero-ext)
end:
    jal   zero, end
