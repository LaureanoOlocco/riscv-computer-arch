# RISC-V Computer Architecture

Implementacion en Verilog/SystemVerilog de un sistema RISC-V RV32I para FPGA, con CPU pipeline de 5 etapas, unidad de debug por UART y herramientas de host para ensamblar, cargar y controlar firmware.

El repositorio ya contiene documentacion por modulo en `modules/**/docs`. Esta pagina funciona como entrada principal del proyecto.

## Caracteristicas

- CPU RV32I de 32 bits con pipeline IF, ID, EX, MEM y WB.
- Manejo de hazards de datos con stalls y forwarding en ID, EX y MEM.
- Manejo de hazards de control para saltos y branches resueltos en ID.
- Memoria de instrucciones y memoria de datos basadas en `block_ram`.
- Unidad de debug por UART para cargar firmware, correr, pausar, ejecutar pasos, leer registros, leer memoria y configurar breakpoints.
- UART 115200 8N1 por defecto, con FIFOs RX/TX.
- Top para FPGA Nexys 4 con constraints en `boards/Nexys-4-Master.xdc`.
- Scripts Python para ensamblar RV32I y comunicarse con la debug unit.

## Estructura

| Ruta | Contenido |
|------|-----------|
| `modules/cpu/` | CPU, ALU, control, hazards, pipeline registers, memorias, muxes, PC y regfile. |
| `modules/debug_unit/` | Controlador de debug, protocolo UART, carga de IMEM, lectura de registros/memoria y breakpoints. |
| `modules/uart/` | UART RX/TX, generador de baud rate, FIFO e interfaz legacy. |
| `modules/top/` | Integracion de CPU, debug unit, UART, FIFOs y wrapper de FPGA. |
| `scripts/` | Ensamblador RV32I simple y clientes de debug/carga. |
| `code/asm/` | Programas de ejemplo en assembler RV32I. |
| `code/bin/` | Binarios de ejemplo generados para cargar en IMEM. |
| `boards/` | Constraints de placa. |
| `docs/` | Documentacion de arquitectura, protocolo y flujo de desarrollo. |

## Lectura recomendada

- [Arquitectura del sistema](docs/ARCHITECTURE.md)
- [Protocolo de debug UART](docs/DEBUG_PROTOCOL.md)
- [Desarrollo, simulacion y FPGA](docs/DEVELOPMENT.md)

## Requisitos

- Python 3.
- `pyserial` para usar el cliente UART: `python3 -m pip install pyserial`.
- Icarus Verilog u otro simulador compatible con Verilog/SystemVerilog para testbenches.
- Vivado para sintesis/implementacion FPGA.
- En Vivado, generar un IP `clk_wiz_0` con entrada de 100 MHz y salida de 75 MHz, porque `modules/top/top_wrapper.v` lo instancia.

## Uso rapido

Ensamblar un programa RV32I:

```bash
python3 scripts/parser.py code/asm/test_program.s code/bin/test_program.bin -v
```

Abrir la shell de debug por UART:

```bash
python3 scripts/debug_client.py /dev/ttyUSB0 115200
```

Comandos utiles dentro de la shell:

```text
sync
load code/bin/test_program.bin
reset
run
halt
step 5
rr 255
rm 0x00
bkp 0x20
clr 0x20
```

En Windows se puede cargar firmware con:

```bash
python scripts/load_program_windows.py COM3 115200 code/bin/test_program.bin
```

## Simulacion

No hay un `Makefile` global en el repo. Los testbenches se compilan indicando el test y sus dependencias RTL. Ejemplo simple para la ALU:

```bash
mkdir -p build
iverilog -g2012 -o build/alu_tb.vvp modules/cpu/alu/rtl/alu.v modules/cpu/alu/tests/alu_tb.sv
vvp build/alu_tb.vvp
```

Para testbenches integrados, agregar todos los modulos RTL instanciados por el DUT. Ver [Desarrollo, simulacion y FPGA](docs/DEVELOPMENT.md) para mas detalle.

## Top-level FPGA

El top de placa es `modules/top/top_wrapper.v`.

Flujo principal:

1. `top_wrapper` toma el clock de placa de 100 MHz, usa `clk_wiz_0` para generar 75 MHz y sincroniza reset/UART RX.
2. `top` instancia baud rate, UART RX/TX, FIFOs y `cpu_subsystem`.
3. `cpu_subsystem` integra `cpu_core` con `debug_unit_top`.
4. El host se comunica por USB-UART usando `scripts/debug_client.py`.

## Estado actual y limitaciones

- `WRITE_REG` y `WRITE_MEM` existen en el protocolo RTL, pero no estan conectados a nivel `cpu_subsystem/cpu_core`; el cliente Python los reporta como no soportados.
- `READ_LATCH` existe en RTL y transmite 45 bytes con los registros de pipeline, pero la shell Python actual no expone un comando interactivo para usarlo.
- La debug unit usa `NB_ADDR = 8` por defecto para direcciones de debug, mientras IMEM/DMEM tienen `IMEM_ADDR_WIDTH = 10` y `DMEM_ADDR_WIDTH = 10` por defecto. Esto da acceso debug directo a las primeras 256 palabras de memorias de 1024 palabras.
- `step N` habilita la CPU por N ciclos de pipeline. Para avanzar una instruccion completa de IF a WB suelen hacer falta 5 steps.
