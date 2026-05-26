"""
report_metrics.py
Lee los reportes de Vivado en rpt/top_wrapper_clock_utilization_routed/
y muestra un resumen de las métricas de funcionamiento del sistema.

Uso:
    python3 scripts/report_metrics.py
"""

import re
import os

RPT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "rpt", "top_wrapper_clock_utilization_routed"
)

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def read(filename):
    path = os.path.join(RPT_DIR, filename)
    if not os.path.exists(path):
        return ""
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()

def find(pattern, text, default="N/A"):
    m = re.search(pattern, text)
    return m.group(1).strip() if m else default

def section(title):
    print(f"\n{'─'*60}")
    print(f"  {title}")
    print(f"{'─'*60}")

# ─────────────────────────────────────────────────────────────────────────────
# 1. Timing Summary
# ─────────────────────────────────────────────────────────────────────────────

def parse_timing():
    txt = read("top_wrapper_timing_summary_routed.rpt")
    section("TIMING")

    # Estado general
    if "All user specified timing constraints are met" in txt:
        print("  Estado         : ✓  TIMING CUMPLIDO")
    elif "Timing constraints are not met" in txt:
        print("  Estado         : ✗  TIMING VIOLADO")
    else:
        print("  Estado         : ?  Sin información")

    # Tabla de design timing summary — línea con los valores numéricos
    m = re.search(
        r"WNS\(ns\).*?TNS\(ns\).*?\n\s*[-\s]+\n\s*([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)"
        r"\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)\s+(\d+)"
        r"\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)",
        txt, re.DOTALL
    )
    if m:
        wns, tns, tns_fail, tns_total = m.group(1), m.group(2), m.group(3), m.group(4)
        whs, ths, ths_fail, ths_total = m.group(5), m.group(6), m.group(7), m.group(8)
        wpws = m.group(9)
        print(f"  WNS  (setup)   : {float(wns):+.3f} ns")
        print(f"  TNS  (setup)   : {float(tns):+.3f} ns   ({tns_fail} endpoints fallando / {tns_total} total)")
        print(f"  WHS  (hold)    : {float(whs):+.3f} ns")
        print(f"  THS  (hold)    : {float(ths):+.3f} ns   ({ths_fail} endpoints fallando / {ths_total} total)")
        print(f"  WPWS (pulso)   : {float(wpws):+.3f} ns")

    # Reloj y frecuencia
    m = re.search(r"clk_out1_\S+\s+\{[^}]+\}\s+([\d.]+)\s+([\d.]+)", txt)
    if m:
        period, freq = m.group(1), m.group(2)
        print(f"  Reloj sistema  : {freq} MHz  (período {period} ns)")

    # Camino crítico (peor slack)
    m = re.search(
        r"Slack \((?:MET|VIOLATED)\)\s*:\s*([-\d.]+)ns.*?"
        r"Source:\s+(\S+).*?"
        r"Destination:\s+(\S+).*?"
        r"Data Path Delay:\s+([\d.]+)ns.*?"
        r"Logic Levels:\s+(\d+)",
        txt, re.DOTALL
    )
    if m:
        print(f"\n  Camino crítico:")
        print(f"    Slack          : {float(m.group(1)):+.3f} ns")
        print(f"    Source         : {m.group(2)}")
        print(f"    Destination    : {m.group(3)}")
        print(f"    Data path      : {m.group(4)} ns")
        print(f"    Niveles lógicos: {m.group(5)}")

    # Skew del camino crítico
    m_skew = re.search(r"Clock Path Skew:\s*([-\d.]+)ns", txt)
    if m_skew:
        print(f"    Clock skew     : {float(m_skew.group(1)):+.3f} ns")

# ─────────────────────────────────────────────────────────────────────────────
# 2. Utilización de Recursos
# ─────────────────────────────────────────────────────────────────────────────

def parse_utilization():
    txt = read("top_wrapper_utilization_placed.rpt")
    section("UTILIZACIÓN DE RECURSOS")

    rows = [
        ("LUT as Logic",     r"LUT as Logic\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*\d+\s*\|\s*(\d+)\s*\|\s*([\d.]+)"),
        ("Slice Registers",  r"Slice Registers\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*\d+\s*\|\s*(\d+)\s*\|\s*([\d.]+)"),
        ("Block RAM Tile",   r"Block RAM Tile\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*\d+\s*\|\s*(\d+)\s*\|\s*([\d.]+)"),
        ("DSPs",             r"DSPs\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*\d+\s*\|\s*(\d+)\s*\|\s*([\d.]+)"),
        ("Bonded IOB",       r"Bonded IOB\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*\d+\s*\|\s*(\d+)\s*\|\s*([\d.]+)"),
        ("MMCME2_ADV",       r"MMCME2_ADV\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*\d+\s*\|\s*(\d+)\s*\|\s*([\d.]+)"),
    ]
    print(f"  {'Recurso':<20} {'Usado':>8} {'Disponible':>12} {'Util%':>8}")
    print(f"  {'─'*20} {'─'*8} {'─'*12} {'─'*8}")
    for label, pat in rows:
        m = re.search(pat, txt)
        if m:
            print(f"  {label:<20} {m.group(1):>8} {m.group(2):>12} {float(m.group(3)):>7.2f}%")

# ─────────────────────────────────────────────────────────────────────────────
# 3. Potencia
# ─────────────────────────────────────────────────────────────────────────────

def parse_power():
    txt = read("top_wrapper_power_routed.rpt")
    section("POTENCIA")

    fields = [
        ("Total On-Chip (W)",   r"Total On-Chip Power \(W\)\s*\|\s*([\d.]+)"),
        ("Dinámica (W)",        r"Dynamic \(W\)\s*\|\s*([\d.]+)"),
        ("Estática (W)",        r"Device Static \(W\)\s*\|\s*([\d.]+)"),
        ("Temp. juntura (°C)",  r"Junction Temperature \(C\)\s*\|\s*([\d.]+)"),
        ("Temp. máx. amb (°C)", r"Max Ambient \(C\)\s*\|\s*([\d.]+)"),
    ]
    for label, pat in fields:
        val = find(pat, txt)
        print(f"  {label:<25} : {val}")

# ─────────────────────────────────────────────────────────────────────────────
# 4. Árbol de Clock (skew y distribución)
# ─────────────────────────────────────────────────────────────────────────────

def parse_clock():
    txt = read("top_wrapper_clock_utilization_routed.rpt")
    section("ÁRBOL DE CLOCK")

    # BUFGs usados
    m = re.search(r"BUFGCTRL\s*\|\s*(\d+)\s*\|\s*(\d+)", txt)
    if m:
        print(f"  BUFGs usados   : {m.group(1)} / {m.group(2)}")

    # MMCM
    m = re.search(r"MMCM\s*\|\s*(\d+)\s*\|\s*(\d+)", txt)
    if m:
        print(f"  MMCM usados    : {m.group(1)} / {m.group(2)}")

    # Clock global g0 — período y cargas
    # Columnas: GlobalId | SourceId | Type | Constraint | Site | Region |
    #           LoadClockRegion | ClockLoads | NonClockLoads | ClockPeriod | ClockName
    m = re.search(
        r"g0\s+\|\s+src0\s+\|\s+BUFG/O\s+\|\s+\S+\s+\|\s+\S+\s+\|\s+\S+\s+\|"
        r"\s+(\d+)\s+\|\s+(\d+)\s+\|\s+(\d+)\s+\|\s+([\d.]+)\s+\|\s+(\S+)",
        txt
    )
    if m:
        clock_loads, period, clock_name = m.group(2), m.group(4), m.group(5)
        print(f"  Clock (g0)     : {clock_name}")
        print(f"    Período       : {period} ns  →  {1000/float(period):.1f} MHz")
        print(f"    Cargas totales: {clock_loads} FFs/BRAMs")

    # Regiones de clock activas
    region_pat = re.compile(
        r"\|\s*(X\dY\d)\s*\|[^|]+\|[^|]+\|[^|]+\|[^|]+\|[^|]+\|[^|]+\|[^|]+\|[^|]+\|[^|]+\|"
        r"[^|]+\|\s+(\d+)\s*\|"
    )
    regiones = [(r, c) for r, c in region_pat.findall(txt) if int(c) > 0]
    if regiones:
        print(f"  Regiones activas:")
        for region, ffs in regiones:
            print(f"    {region} : {ffs} FFs")

# ─────────────────────────────────────────────────────────────────────────────
# 5. Bus Skew
# ─────────────────────────────────────────────────────────────────────────────

def parse_bus_skew():
    txt = read("top_wrapper_bus_skew_routed.rpt")
    section("BUS SKEW")

    if "No bus skew constraints" in txt:
        print("  Sin constraints de bus skew.")
        print("  → Correcto para diseño de dominio único (single clock domain).")
    else:
        violations = re.findall(r"VIOLATED.*?slack\s+([-\d.]+)", txt, re.DOTALL)
        if violations:
            print(f"  Violations encontradas: {len(violations)}")
            for v in violations:
                print(f"    Slack: {v} ns")
        else:
            print("  Sin violaciones de bus skew.")

# ─────────────────────────────────────────────────────────────────────────────
# 6. Methodology DRC
# ─────────────────────────────────────────────────────────────────────────────

def parse_methodology():
    txt = read("top_wrapper_methodology_drc_routed.rpt")
    section("METHODOLOGY DRC")

    m = re.search(r"Checks found:\s*(\d+)", txt)
    total = int(m.group(1)) if m else 0
    print(f"  Checks encontrados: {total}")

    rows = re.findall(
        r"\|\s*([\w-]+)\s*\|\s*([\w ]+?)\s*\|\s*(.+?)\s*\|\s*(\d+)\s*\|",
        txt
    )
    for rule, severity, desc, count in rows:
        if rule.startswith("─") or rule == "Rule":
            continue
        sev = severity.strip()
        icon = "✗" if "Critical" in sev else "⚠"
        print(f"  {icon} {rule:<12} [{sev}]  {desc[:55]}")

# ─────────────────────────────────────────────────────────────────────────────
# 7. DRC Routed
# ─────────────────────────────────────────────────────────────────────────────

def parse_drc():
    txt = read("top_wrapper_drc_routed.rpt")
    section("DRC (DISEÑO RUTEADO)")

    m = re.search(r"Checks found:\s*(\d+)", txt)
    n = m.group(1) if m else "?"
    if n == "0":
        print(f"  Violations: {n}  ✓")
    else:
        print(f"  Violations: {n}  ✗")
        for rule, sev, desc, checks in re.findall(
            r"\|\s*([\w-]+)\s*\|\s*([\w ]+?)\s*\|\s*(.+?)\s*\|\s*(\d+)\s*\|", txt
        ):
            if rule not in ("Rule", "─"):
                print(f"    {rule}: {desc.strip()} ({checks})")

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("=" * 60)
    print("  MÉTRICAS DE FUNCIONAMIENTO — top_wrapper (RISC-V)")
    print(f"  Fuente: {RPT_DIR}")
    print("=" * 60)

    parse_timing()
    parse_utilization()
    parse_power()
    parse_clock()
    parse_bus_skew()
    parse_methodology()
    parse_drc()

    print(f"\n{'═'*60}\n")
