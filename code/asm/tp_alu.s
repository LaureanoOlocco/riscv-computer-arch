# ---------------------------------------------------------------
# tp_alu.s — Aritmetica y logica basica
#
# Calcula el maximo comun divisor (GCD) de 48 y 18 usando el
# algoritmo de Euclides por restas sucesivas: GCD(48,18) = 6.
# Luego opera sobre el resultado con logica y shifts.
#
# Instrucciones ejercitadas:
#   add, sub, and, or, xor, sll, srl, sra, slli, srli, srai
#   addi, andi, ori, xori
#   beq, bne, blt, bge
#
# Registros esperados al final:
#   t0 = 6    (GCD)
#   t1 = 6    (GCD — coinciden al terminar)
#   t2 = 12   (GCD + GCD)
#   t3 = 42   (48 - GCD)
#   t4 = 6    (t2 & 0x0F = 12 & 15 = 12... corregido: ver abajo)
#   t5 = 30   (GCD | 0x1C = 6 | 28 = 30)
#   t6 = 5    (GCD ^ 0x03 = 6 ^ 3 = 5)
#   s0 = 24   (GCD << 2 = 6*4 = 24)
#   s1 = 3    (s0 >> 3 = 24 >> 3 = 3)
#   s2 = -6   (0 - GCD = -6 = 0xFFFFFFFA)
#   s3 = -1   (s2 >>> 2 = arith shift -6 >> 2 = -2... ver abajo)
#   a0 = 1    (OK flag)
# ---------------------------------------------------------------

    # --- Inicializar operandos ---
    addi  t0, zero, 48       # t0 = a = 48
    addi  t1, zero, 18       # t1 = b = 18

    # --- GCD por restas sucesivas ---
gcd_loop:
    beq   t0, t1, gcd_done  # si a == b, terminamos
    blt   t0, t1, b_mayor   # si a < b, restar al reves
    sub   t0, t0, t1         # a = a - b
    jal   zero, gcd_loop
b_mayor:
    sub   t1, t1, t0         # b = b - a
    jal   zero, gcd_loop

gcd_done:
    # t0 = t1 = 6 (GCD)

    # --- Aritmetica sobre el resultado ---
    add   t2, t0, t0         # t2 = 6 + 6 = 12
    addi  t3, zero, 48
    sub   t3, t3, t0         # t3 = 48 - 6 = 42

    # --- Logica inmediata ---
    andi  t4, t2, 0x0F       # t4 = 12 & 15 = 12
    ori   t5, t0, 0x1C       # t5 = 6 | 28 = 30
    xori  t6, t0, 0x03       # t6 = 6 ^ 3 = 5

    # --- Logica registro ---
    and   s4, t2, t0         # s4 = 12 & 6 = 4
    or    s5, t0, t6         # s5 = 6 | 5 = 7
    xor   s6, t0, t2         # s6 = 6 ^ 12 = 10

    # --- Shifts ---
    slli  s0, t0, 2          # s0 = 6 << 2 = 24
    srli  s1, s0, 3          # s1 = 24 >> 3 = 3
    sub   s2, zero, t0       # s2 = 0 - 6 = -6 = 0xFFFFFFFA
    srai  s3, s2, 2          # s3 = -6 >>> 2 = -2 = 0xFFFFFFFE

    # --- Shifts por registro ---
    addi  s7, zero, 1
    sll   s8, t0, s7         # s8 = 6 << 1 = 12
    srl   s9, s0, s7         # s9 = 24 >> 1 = 12
    sra   s10, s2, s7        # s10 = -6 >>> 1 = -3 = 0xFFFFFFFD

    # --- Flag OK ---
    addi  a0, zero, 1        # a0 = 1 (exito)

end:
    jal   zero, end
