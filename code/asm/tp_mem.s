# ---------------------------------------------------------------
# tp_mem.s — Accesos a memoria: word, half, byte con signo
#
# Escribe un arreglo de 4 temperaturas (con signo) en DMEM como
# bytes, las relee con y sin extension de signo, acumula la suma
# total, y guarda resultados como halfword y word.
#
# Instrucciones ejercitadas:
#   sb, sh, sw
#   lb, lbu, lh, lhu, lw
#   addi, add, srai
#
# Temperaturas: +25, -10, +30, -5
#
# Registros esperados al final:
#   t0 = 25    (temp[0] releida con lb, sign-ext)
#   t1 = -10   (temp[1] releida con lb = 0xFFFFFFF6)
#   t2 = 30    (temp[2])
#   t3 = -5    (temp[3] = 0xFFFFFFFB)
#   t4 = 40    (suma = 25 + (-10) + 30 + (-5) = 40)
#   t5 = 10    (promedio = 40 / 4 = 40 >>> 2 = 10)
#   a0 = 25    (temp[0] con lbu = 0x19, sin sign-ext)
#   a1 = 246   (temp[1] con lbu = 0xF6 = 246)
#   a2 = 40    (suma releida con lh desde DMEM)
#   a3 = 40    (suma releida con lhu)
#   a4 = 10    (promedio releido con lw desde DMEM)
#
# Mapa DMEM:
#   0x00: temp[0] (byte)
#   0x01: temp[1] (byte)
#   0x02: temp[2] (byte)
#   0x03: temp[3] (byte)
#   0x04: suma    (halfword)
#   0x08: promedio (word)
# ---------------------------------------------------------------

    addi  sp, zero, 0        # base DMEM

    # --- Escribir temperaturas como bytes ---
    addi  s0, zero, 25
    sb    s0, 0(sp)           # MEM[0] = 25

    addi  s1, zero, -10
    sb    s1, 1(sp)           # MEM[1] = 0xF6 (-10 en complemento a 2)

    addi  s2, zero, 30
    sb    s2, 2(sp)           # MEM[2] = 30

    addi  s3, zero, -5
    sb    s3, 3(sp)           # MEM[3] = 0xFB (-5)

    # --- Releer con extension de signo (lb) ---
    lb    t0, 0(sp)           # t0 = 25
    lb    t1, 1(sp)           # t1 = 0xFFFFFFF6 = -10
    lb    t2, 2(sp)           # t2 = 30
    lb    t3, 3(sp)           # t3 = 0xFFFFFFFB = -5

    # --- Releer sin extension de signo (lbu) ---
    lbu   a0, 0(sp)           # a0 = 25
    lbu   a1, 1(sp)           # a1 = 246

    # --- Sumar temperaturas ---
    add   t4, t0, t1          # t4 = 25 + (-10) = 15
    add   t4, t4, t2          # t4 = 15 + 30 = 45
    add   t4, t4, t3          # t4 = 45 + (-5) = 40

    # --- Promedio (dividir por 4 con shift aritmetico) ---
    srai  t5, t4, 2           # t5 = 40 >> 2 = 10

    # --- Guardar resultados en DMEM ---
    sh    t4, 4(sp)           # MEM[4..5] = 40 (halfword)
    sw    t5, 8(sp)           # MEM[8..11] = 10 (word)

    # --- Releer resultados con distintos tamanios ---
    lh    a2, 4(sp)           # a2 = 40 (sign-ext halfword)
    lhu   a3, 4(sp)           # a3 = 40 (zero-ext halfword)
    lw    a4, 8(sp)           # a4 = 10 (word)

end:
    jal   zero, end
