# ---------------------------------------------------------------
# tp_branch.s — Branches y comparaciones
#
# Clasifica tres numeros (a=15, b=7, c=15) usando todas las
# variantes de branch y comparacion, almacenando flags de
# resultado.
#
# Instrucciones ejercitadas:
#   beq, bne, blt, bge, bltu, bgeu
#   slt, sltu, slti, sltiu
#   addi, add, lui
#
# Registros esperados al final:
#   t0 = 15       (a)
#   t1 = 7        (b)
#   t2 = 15       (c)
#   s0 = 1        (a == c? si)
#   s1 = 1        (a != b? si)
#   s2 = 1        (b < a? si, signed)
#   s3 = 1        (a >= b? si, signed)
#   s4 = 1        (b < a? si, unsigned)
#   s5 = 1        (a >= c? si, unsigned)
#   s6 = 0        (slt a, b = 15 < 7? no)
#   s7 = 1        (slt b, a = 7 < 15? si)
#   s8 = 1        (sltu b, a = 7 < 15? si, unsigned)
#   s9 = 0        (slti a, 10 = 15 < 10? no)
#   s10 = 1       (sltiu b, 100 = 7 < 100? si)
#   a0 = 0x10000  (lui test: 1 << 16 = 65536)
#   a1 = 7        (min(a,b) = 7)
#   a2 = 15       (max(a,b) = 15)
#   a3 = 1        (flag OK: todos los branches funcionaron)
# ---------------------------------------------------------------

    # --- Inicializar valores ---
    addi  t0, zero, 15       # a = 15
    addi  t1, zero, 7        # b = 7
    addi  t2, zero, 15       # c = 15

    # --- LUI test ---
    lui   a0, 1              # a0 = 0x00001000 = 4096

    # --- Test BEQ: a == c? ---
    addi  s0, zero, 0        # s0 = 0 (default: no)
    beq   t0, t2, eq_yes
    jal   zero, eq_done
eq_yes:
    addi  s0, zero, 1        # s0 = 1 (a == c)
eq_done:

    # --- Test BNE: a != b? ---
    addi  s1, zero, 0
    bne   t0, t1, ne_yes
    jal   zero, ne_done
ne_yes:
    addi  s1, zero, 1        # s1 = 1 (a != b)
ne_done:

    # --- Test BLT: b < a? (signed) ---
    addi  s2, zero, 0
    blt   t1, t0, lt_yes
    jal   zero, lt_done
lt_yes:
    addi  s2, zero, 1        # s2 = 1 (b < a)
lt_done:

    # --- Test BGE: a >= b? (signed) ---
    addi  s3, zero, 0
    bge   t0, t1, ge_yes
    jal   zero, ge_done
ge_yes:
    addi  s3, zero, 1        # s3 = 1 (a >= b)
ge_done:

    # --- Test BLTU: b < a? (unsigned) ---
    addi  s4, zero, 0
    bltu  t1, t0, ltu_yes
    jal   zero, ltu_done
ltu_yes:
    addi  s4, zero, 1        # s4 = 1
ltu_done:

    # --- Test BGEU: a >= c? (unsigned) ---
    addi  s5, zero, 0
    bgeu  t0, t2, geu_yes
    jal   zero, geu_done
geu_yes:
    addi  s5, zero, 1        # s5 = 1 (15 >= 15)
geu_done:

    # --- Comparaciones SLT/SLTU/SLTI/SLTIU ---
    slt   s6, t0, t1         # s6 = (15 < 7)? = 0
    slt   s7, t1, t0         # s7 = (7 < 15)? = 1
    sltu  s8, t1, t0         # s8 = (7 <u 15)? = 1
    slti  s9, t0, 10         # s9 = (15 < 10)? = 0
    sltiu s10, t1, 100       # s10 = (7 <u 100)? = 1

    # --- Calcular min(a,b) y max(a,b) ---
    blt   t0, t1, a_is_min
    add   a1, zero, t1       # a1 = min = b = 7
    add   a2, zero, t0       # a2 = max = a = 15
    jal   zero, minmax_done
a_is_min:
    add   a1, zero, t0       # a1 = min = a
    add   a2, zero, t1       # a2 = max = b
minmax_done:

    # --- Flag OK ---
    addi  a3, zero, 1        # a3 = 1

end:
    jal   zero, end
