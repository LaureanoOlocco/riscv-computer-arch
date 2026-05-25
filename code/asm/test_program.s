# ---------------------------------------------------------------
# Programa de prueba RV32I
# Calcula la suma 1+2+...+10 = 55, la guarda en DMEM,
# la relee y hace varias operaciones de verificacion.
#
# Ejercita:
#   - I-type aritmetica (addi)
#   - R-type (add, sub, xor, and, or)
#   - Shifts inmediatos (slli)
#   - Loop con branch (bge)
#   - Memoria (sw, lw)
#   - Salto incondicional (jal)
#   - Branch de igualdad (beq)
#
# IMEM y DMEM son independientes (1024 words cada una),
# asi que podemos usar sp = 0 como base de datos sin conflicto.
# ---------------------------------------------------------------

    # --- Inicializacion ---
    addi t0, zero, 1        # t0 = i = 1
    addi t1, zero, 10       # t1 = limite = 10
    addi t2, zero, 0        # t2 = acumulador = 0
    addi sp, zero, 0        # sp = 0 (base de DMEM)

# --- Loop: acumular 1..10 en t2 ---
loop:
    add  t2, t2, t0         # acum += i
    addi t0, t0, 1          # i++
    bge  t1, t0, loop       # si (10 >= i) repetir
                            # al salir: t2 = 55 (0x37)

    # --- Guardar resultados en DMEM ---
    sw   t2, 0(sp)          # MEM[0] = 55
    addi t3, zero, 100
    sw   t3, 4(sp)          # MEM[4] = 100

    # --- Releer desde DMEM ---
    lw   t4, 0(sp)          # t4 = 55
    lw   t5, 4(sp)          # t5 = 100

    # --- Operaciones R-type e inmediatas ---
    add  t6, t4, t5         # t6 = 155
    sub  s0, t5, t4         # s0 = 45
    xor  s1, t4, t5         # s1 = 55 ^ 100 = 83
    and  s2, t4, t5         # s2 = 55 & 100 = 32
    or   s3, t4, t5         # s3 = 55 | 100 = 119
    slli s4, t4, 2          # s4 = 55 << 2 = 220

    # --- Verificacion: si t4 == 55, a0 = 1; si no, a0 = -1 ---
    addi s5, zero, 55
    beq  t4, s5, ok
    addi a0, zero, -1       # ERROR
    jal  zero, end

ok:
    addi a0, zero, 1        # OK

# --- Halt: loop infinito sobre si mismo ---
end:
    jal  zero, end
