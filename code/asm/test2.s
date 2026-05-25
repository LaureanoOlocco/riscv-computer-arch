# ---------------------------------------------------------------
# test2.s — Programa de prueba exhaustivo para debug unit
#
# Ejercita instrucciones NO cubiertas por test_program.s:
#   - lui / auipc
#   - jalr (call/return simulado)
#   - slt / sltu / slti / sltiu
#   - srl / sra / srli / srai
#   - sll
#   - bne / blt / bltu / bgeu
#   - lbu / lhu / lb / lh / sb / sh
#   - xori / andi / ori
#   - Hazard load-use (lw seguido inmediatamente de uso)
#   - Forward de resultado R-type al siguiente
# ---------------------------------------------------------------

    # ---- 1. LUI / AUIPC ----
    lui   a0, 1             # a0 = 0x00001000
    auipc a1, 0             # a1 = PC de esta instruccion

    # ---- 2. Shifts ----
    addi  t0, zero, 1
    sll   t1, t0, t0        # t1 = 1 << 1 = 2
    slli  t2, t0, 4         # t2 = 1 << 4 = 16
    addi  t3, zero, -1      # t3 = 0xFFFFFFFF
    srl   t4, t3, t0        # t4 = 0x7FFFFFFF (logical shift)
    sra   t5, t3, t0        # t5 = 0xFFFFFFFF (arithmetic shift)
    srli  t6, t3, 4         # t6 = 0x0FFFFFFF
    srai  s0, t3, 4         # s0 = 0xFFFFFFFF

    # ---- 3. SLT / SLTU ----
    addi  s1, zero, 5
    addi  s2, zero, 10
    slt   s3, s1, s2        # s3 = 1 (5 < 10, signed)
    slt   s4, s2, s1        # s4 = 0
    sltu  s5, t0, s2        # s5 = 1 (1 < 10, unsigned)
    slti  s6, s1, 3         # s6 = 0 (5 < 3 es falso)
    sltiu s7, t0, 100       # s7 = 1 (1 < 100)

    # ---- 4. Xori / andi / ori ----
    addi  a2, zero, 0x0F
    xori  a3, a2, 0xFF      # a3 = 0x0F ^ 0xFF = 0xF0 = -16 (sign ext)
    andi  a4, a2, 0x03      # a4 = 0x0F & 0x03 = 0x03
    ori   a5, a2, 0x70      # a5 = 0x0F | 0x70 = 0x7F

    # ---- 5. Store byte/half, load byte/half ----
    addi  sp, zero, 0       # base DMEM = 0
    addi  t0, zero, 0xAB
    sb    t0, 0(sp)         # MEM[0] = 0xAB
    addi  t0, zero, 0x12
    sh    t0, 2(sp)         # MEM[2..3] = 0x0012
    lb    a6, 0(sp)         # a6 = sign_ext(0xAB) = 0xFFFFFFAB
    lbu   a7, 0(sp)         # a7 = 0x000000AB
    lh    s8, 2(sp)         # s8 = sign_ext(0x0012) = 0x00000012
    lhu   s9, 2(sp)         # s9 = 0x00000012

    # ---- 6. Hazard load-use ----
    addi  t0, zero, 42
    sw    t0, 8(sp)         # MEM[8] = 42
    lw    t1, 8(sp)         # t1 = 42  (load)
    addi  t2, t1, 1         # t2 = 43  (usa t1 inmediatamente — load-use hazard)
    add   t3, t1, t2        # t3 = 85  (forwarding desde load y R-type)

    # ---- 7. Branches variados ----
    addi  t0, zero, 7
    addi  t1, zero, 7
    beq   t0, t1, beq_ok   # debe saltar
    addi  a0, zero, -1      # NO debe ejecutarse
beq_ok:
    bne   t0, t1, end       # NO debe saltar (son iguales)
    addi  t1, zero, 3
    blt   t1, t0, blt_ok   # 3 < 7, debe saltar
    addi  a0, zero, -2      # NO debe ejecutarse
blt_ok:
    addi  t2, zero, 10
    bgeu  t2, t0, bgeu_ok  # 10 >= 7 unsigned, debe saltar
    addi  a0, zero, -3      # NO debe ejecutarse
bgeu_ok:
    bltu  t1, t2, bltu_ok  # 3 < 10 unsigned, debe saltar
    addi  a0, zero, -4      # NO debe ejecutarse
bltu_ok:

    # ---- 8. JALR (simula call/return) ----
    addi  ra, zero, 0       # limpiar ra
    jal   ra, myfunc        # call myfunc, ra = PC+4
    addi  a0, zero, 1       # OK — debe ejecutarse al retornar
    jal   zero, end

myfunc:
    addi  a1, zero, 99      # a1 = 99
    jalr  zero, ra, 0       # return

end:
    jal   zero, end
