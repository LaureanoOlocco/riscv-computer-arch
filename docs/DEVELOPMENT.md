# Desarrollo, Simulacion y FPGA

Este documento describe el flujo practico para trabajar con el proyecto.

## Convenciones del repo

Los modulos suelen seguir esta estructura:

```text
modules/<subsystem>/<component>/rtl/
modules/<subsystem>/<component>/tests/
modules/<subsystem>/<component>/docs/
```

Excepciones:

- `modules/top/` contiene integracion top-level directamente.
- `modules/cpu/hazard/rtl/cpu_core.v` contiene el core completo integrado.
- `boards/` contiene constraints de FPGA.
- `scripts/` contiene herramientas de host.

## Ensamblar firmware

El ensamblador simple esta en `scripts/parser.py`. Soporta un subconjunto RV32I, labels, comentarios y nombres ABI de registros.

Ejemplo:

```bash
python3 scripts/parser.py code/asm/test_program.s code/bin/test_program.bin -v
```

El binario resultante contiene instrucciones de 32 bits little-endian, listas para cargar por debug UART.

## Usar la shell de debug

Instalar dependencia Python:

```bash
python3 -m pip install pyserial
```

Abrir shell:

```bash
python3 scripts/debug_client.py /dev/ttyUSB0 115200
```

Flujo tipico:

```text
sync
load code/bin/test_program.bin
reset
run
status
halt
rr 255
rm 0x00
```

Notas:

- `load` agrega `0x1A1A1A1A` al final por defecto como instruccion de halt.
- `rr 255` hace dump de PC + 32 registros.
- `wr` y `wm` aparecen en la ayuda pero no estan soportados por la integracion actual de CPU.

## Simular modulos

No hay runner global. Compilar cada testbench con sus dependencias RTL.

Ejemplo ALU:

```bash
mkdir -p build
iverilog -g2012 -o build/alu_tb.vvp modules/cpu/alu/rtl/alu.v modules/cpu/alu/tests/alu_tb.sv
vvp build/alu_tb.vvp
```

Ejemplo UART TX:

```bash
mkdir -p build
iverilog -g2012 -o build/uart_tx_tb.vvp modules/uart/core/rtl/uart_tx.v modules/uart/core/tests/uart_tx_tb.sv
vvp build/uart_tx_tb.vvp
```

Para testbenches integrados, incluir todos los RTL que instancia el DUT. Si aparece un error como `Unknown module type`, falta agregar una dependencia RTL al comando de compilacion.

## Agregar o modificar un modulo

Checklist recomendado:

1. Mantener el modulo sintetizable y parametrizable cuando aplique.
2. Agregar o actualizar testbench en `tests/`.
3. Agregar o actualizar doc en `docs/` con descripcion, parametros, puertos y comportamiento.
4. Verificar que el testbench compile con `iverilog -g2012` u otro simulador usado por el equipo.
5. Si el cambio afecta top-level, revisar `modules/top/top.v`, `modules/top/cpu_subsystem.v` y `modules/top/top_wrapper.v`.

## FPGA con Vivado

Top de placa:

```text
modules/top/top_wrapper.v
```

Constraints:

```text
boards/Nexys-4-Master.xdc
```

Puntos importantes:

- Generar el IP `clk_wiz_0` en Vivado.
- Configurar `clk_wiz_0` con entrada 100 MHz y salida 75 MHz.
- Agregar todos los RTL bajo `modules/` al proyecto Vivado.
- Setear `top_wrapper` como top.
- Usar los puertos `clock`, `i_rst`, `i_uart_rx` y `o_uart_tx` definidos en el XDC.

Despues de programar la FPGA:

1. Liberar reset fisico.
2. Abrir el puerto serie a 115200 baudios.
3. Ejecutar `sync` desde `scripts/debug_client.py`.
4. Cargar firmware y controlar la CPU desde la shell.

## Documentacion por modulo

La documentacion existente cubre los bloques principales:

- CPU: `modules/cpu/**/docs/*.md`.
- UART: `modules/uart/**/docs/*.md`.
- Debug unit: `modules/debug_unit/**/docs/*.md`.

Cuando se agregue un modulo nuevo, seguir el formato usado en esas guias: titulo, proyecto/autores/fecha, descripcion, parametros, puertos, comportamiento, FSM si aplica y notas de diseno.
