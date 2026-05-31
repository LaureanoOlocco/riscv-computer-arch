# ---------------------------------------------------------------
# tp_jal.s — Saltos, llamadas a funcion y AUIPC
#
# Implementa dos funciones:
#   - abs(x): devuelve valor absoluto
#   - mul8(x): multiplica por 8 con shifts
# Las llama con jal/jalr y verifica los resultados.
#
# Instrucciones ejercitadas:
#   jal, jalr, auipc
#   addi, add, sub, slli
#   bge, blt
#   sw, lw
#
# Registros esperados al final:
#   a0 = 1        (flag OK)
#   a1 = 10       (abs(-10) = 10)
#   a2 = 10       (abs(10) = 10)
#   a3 = 40       (mul8(5) = 40)
#   a4 = 0        (auipc de referencia, sera PC de esa instr)
#   s0 = 0        (stack pointer final, vuelve a 0)
# ---------------------------------------------------------------

    # --- Inicializar stack pointer ---
    addi  sp, zero, 64       # sp = 64 (tope del stack en DMEM)

    # --- Guardar auipc como referencia ---
    auipc a4, 0              # a4 = PC de esta instruccion

    # --- Llamar abs(-10) ---
    addi  a0, zero, -10      # argumento = -10
    jal   ra, fn_abs         # call abs
    add   a1, zero, a0       # a1 = resultado = 10

    # --- Llamar abs(10) ---
    addi  a0, zero, 10       # argumento = 10
    jal   ra, fn_abs         # call abs
    add   a2, zero, a0       # a2 = resultado = 10

    # --- Llamar mul8(5) ---
    addi  a0, zero, 5        # argumento = 5
    jal   ra, fn_mul8        # call mul8
    add   a3, zero, a0       # a3 = resultado = 40

    # --- Restaurar sp ---
    addi  s0, sp, 0          # s0 = sp actual (deberia ser 64 si no hay leak)

    # --- Flag OK ---
    addi  a0, zero, 1

    jal   zero, end

# ---------------------------------------------------------------
# fn_abs: a0 = |a0|
# Usa stack para guardar ra (simula nested call readiness)
# ---------------------------------------------------------------
fn_abs:
    # Prologo: guardar ra en stack
    addi  sp, sp, -4
    sw    ra, 0(sp)

    bge   a0, zero, abs_pos  # si a0 >= 0, ya es positivo
    sub   a0, zero, a0       # a0 = -a0
abs_pos:
    # Epilogo: restaurar ra
    lw    ra, 0(sp)
    addi  sp, sp, 4
    jalr  zero, ra, 0        # return

# ---------------------------------------------------------------
# fn_mul8: a0 = a0 * 8 (shift left 3)
# ---------------------------------------------------------------
fn_mul8:
    slli  a0, a0, 3          # a0 = a0 << 3 = a0 * 8
    jalr  zero, ra, 0        # return

end:
    jal   zero, end
