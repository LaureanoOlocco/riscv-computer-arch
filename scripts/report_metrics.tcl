# =============================================================================
# report_metrics.tcl
# Genera los reportes de funcionamiento del diseño top_wrapper.
#
# Uso desde Vivado Tcl Console (con proyecto abierto y ruteado):
#   source scripts/report_metrics.tcl
#
# Uso desde checkpoint (sin proyecto abierto):
#   open_checkpoint <ruta>/top_wrapper_routed.dcp
#   source scripts/report_metrics.tcl
# =============================================================================

set rpt_dir "rpt/top_wrapper_clock_utilization_routed"

puts ""
puts "============================================================"
puts " Generando métricas de funcionamiento — top_wrapper"
puts "============================================================"

# -----------------------------------------------------------------------------
# 1. Timing Summary
#    WNS / TNS (setup), WHS / THS (hold), camino crítico, skew por path.
# -----------------------------------------------------------------------------
puts "\n\[1/7\] Timing Summary..."
report_timing_summary \
    -max_paths      10               \
    -report_unconstrained            \
    -warn_on_violation               \
    -file           $rpt_dir/top_wrapper_timing_summary_routed.rpt

# -----------------------------------------------------------------------------
# 2. Camino crítico detallado (top 5 peores paths)
#    Muestra niveles lógicos, retardo de routing vs lógica y skew por path.
# -----------------------------------------------------------------------------
puts "\[2/7\] Camino crítico detallado..."
report_timing \
    -max_paths      5                \
    -path_type      full_clock       \
    -nworst         1                \
    -sort_by        slack            \
    -warn_on_violation               \
    -file           $rpt_dir/top_wrapper_critical_path.rpt

# -----------------------------------------------------------------------------
# 3. Bus Skew
#    Diferencia de llegada entre bits de buses que cruzan dominios de clock.
#    "No bus skew constraints" es el resultado esperado en diseño monodominio.
# -----------------------------------------------------------------------------
puts "\[3/7\] Bus Skew..."
report_bus_skew \
    -warn_on_violation               \
    -file           $rpt_dir/top_wrapper_bus_skew_routed.rpt

# -----------------------------------------------------------------------------
# 4. Utilización de recursos
#    LUTs, FFs, BRAMs, DSPs, IOBs usados vs disponibles.
# -----------------------------------------------------------------------------
puts "\[4/7\] Utilización de recursos..."
report_utilization \
    -file           $rpt_dir/top_wrapper_utilization_placed.rpt

# -----------------------------------------------------------------------------
# 5. Potencia estimada
#    Potencia dinámica y estática, desglosada por tipo de recurso y jerarquía.
# -----------------------------------------------------------------------------
puts "\[5/7\] Potencia..."
report_power \
    -file           $rpt_dir/top_wrapper_power_routed.rpt

# -----------------------------------------------------------------------------
# 6. Árbol de clock
#    Regiones usadas, carga del BUFG, skew del árbol de distribución.
# -----------------------------------------------------------------------------
puts "\[6/7\] Clock utilization..."
report_clock_utilization \
    -file           $rpt_dir/top_wrapper_clock_utilization_routed.rpt

# -----------------------------------------------------------------------------
# 7. Methodology DRC
#    Warnings de metodología: TIMING-6, SYNTH-6, TIMING-56, etc.
# -----------------------------------------------------------------------------
puts "\[7/7\] Methodology DRC..."
report_methodology \
    -file           $rpt_dir/top_wrapper_methodology_drc_routed.rpt

# -----------------------------------------------------------------------------
# Resumen en consola
# -----------------------------------------------------------------------------
puts ""
puts "============================================================"
puts " Resumen de timing"
puts "============================================================"

set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
set whs [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -hold]]

puts [format "  WNS (setup)  : %+.3f ns" $wns]
puts [format "  WHS (hold)   : %+.3f ns" $whs]

if {$wns >= 0} {
    puts "  Setup        : CUMPLE ✓"
} else {
    puts "  Setup        : VIOLADO ✗"
}
if {$whs >= 0} {
    puts "  Hold         : CUMPLE ✓"
} else {
    puts "  Hold         : VIOLADO ✗"
}

puts ""
puts " Reportes generados en: $rpt_dir/"
puts "  - top_wrapper_timing_summary_routed.rpt"
puts "  - top_wrapper_critical_path.rpt"
puts "  - top_wrapper_bus_skew_routed.rpt"
puts "  - top_wrapper_utilization_placed.rpt"
puts "  - top_wrapper_power_routed.rpt"
puts "  - top_wrapper_clock_utilization_routed.rpt"
puts "  - top_wrapper_methodology_drc_routed.rpt"
puts "============================================================"
