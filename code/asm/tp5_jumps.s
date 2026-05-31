# tp5_jumps.s — Saltos y branches unsigned (15 instrucciones)
# Instrucciones: jal, jalr, bltu, bgeu, addi, sw, lw

    addi  sp, zero, 32       # sp = 32 (base stack)
    addi  a0, zero, 5        # a0 = argumento = 5
    jal   ra, fn_doble       # call fn_doble, ra = PC+4
    add   a1, zero, a0       # a1 = 10 (resultado)
    addi  t0, zero, 3        # t0 = 3
    addi  t1, zero, 20       # t1 = 20
    bltu  t0, t1, u_ok       # debe saltar (3 <u 20)
    addi  a2, zero, -1       # NO ejecutar
u_ok:
    bgeu  t1, t0, u2_ok      # debe saltar (20 >=u 3)
    addi  a2, zero, -1       # NO ejecutar
u2_ok:
    addi  a2, zero, 1        # a2 = 1 (branches unsigned OK)
    jal   zero, end

fn_doble:
    addi  sp, sp, -4
    sw    ra, 0(sp)           # guardar ra en stack
    add   a0, a0, a0         # a0 = a0 * 2 = 10
    lw    ra, 0(sp)           # restaurar ra
    addi  sp, sp, 4
    jalr  zero, ra, 0        # return
end:
    jal   zero, end
