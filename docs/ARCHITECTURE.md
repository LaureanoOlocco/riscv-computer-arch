# Arquitectura del Sistema

Este documento resume como se integran los bloques principales del proyecto. La documentacion detallada de cada modulo esta en `modules/**/docs`.

## Vista general

```text
Host PC
  |
  | USB-UART 115200 8N1
  v
top_wrapper
  |
  v
top
  |-- baud_rate_gen
  |-- uart_rx -> RX FIFO
  |-- TX FIFO -> uart_tx
  `-- cpu_subsystem
        |-- cpu_core
        `-- debug_unit_top
```

El sistema corre con un clock interno de 75 MHz. En FPGA, `top_wrapper` espera un clock de placa de 100 MHz y usa el IP `clk_wiz_0` para generar los 75 MHz usados por el resto del diseno.

## Capas top-level

| Modulo | Ruta | Responsabilidad |
|--------|------|-----------------|
| `top_wrapper` | `modules/top/top_wrapper.v` | Wrapper de FPGA, clock wizard, reset combinado y sincronizadores. |
| `top` | `modules/top/top.v` | UART fisica, FIFOs y conexion con `cpu_subsystem`. |
| `cpu_subsystem` | `modules/top/cpu_subsystem.v` | Integra CPU y debug unit, arbitra senales compartidas y registra observabilidad. |
| `cpu_core` | `modules/cpu/hazard/rtl/cpu_core.v` | CPU RV32I pipeline de 5 etapas. |
| `debug_unit_top` | `modules/debug_unit/top/rtl/debug_unit_top.v` | Subsystem de debug y multiplexado de respuestas UART. |

## CPU

`cpu_core` implementa una CPU RV32I con pipeline de 5 etapas:

| Etapa | Funcion principal |
|-------|-------------------|
| IF | PC, lectura de IMEM y calculo de `PC + 4`. |
| ID | Decode, regfile, immediate generator, jumps, branches y forwarding de ID. |
| EX | ALU, ALU control y forwarding de EX. |
| MEM | Acceso a DMEM y forwarding de store data. |
| WB | Seleccion de writeback hacia register file. |

La CPU tiene manejo de hazards:

- Load-use stall con `hazard_detection_unit`.
- Forwarding en ID para branches y JALR.
- Forwarding en EX para operandos de ALU.
- Forwarding en MEM para datos de store.
- Flush de IF/ID para branches tomados y jumps.

## Memorias

La memoria de instrucciones y la memoria de datos usan `block_ram`.

| Memoria | Parametro default | Capacidad default | Acceso CPU | Acceso debug |
|---------|-------------------|-------------------|------------|--------------|
| IMEM | `IMEM_ADDR_WIDTH = 10` | 1024 palabras de 32 bits | Lectura de instrucciones | Escritura para carga de firmware |
| DMEM | `DMEM_ADDR_WIDTH = 10` | 1024 palabras de 32 bits | Load/store | Lectura por debug |

La unidad de debug usa `NB_ADDR = 8` por defecto. `cpu_subsystem` extiende esa direccion a los anchos internos de IMEM/DMEM, por lo que el host accede por defecto a las primeras 256 palabras.

## Debug Unit

La debug unit recibe comandos desde UART y controla la CPU sin requerir un debugger externo JTAG.

Funciones principales:

- Cargar firmware en IMEM.
- Ejecutar, detener y resetear la CPU.
- Ejecutar una cantidad configurable de ciclos de pipeline.
- Leer registros individuales o hacer dump completo de PC + registros.
- Leer memoria de datos.
- Configurar y borrar breakpoints por PC.
- Serializar registros de pipeline mediante `du_latch_tx`.

`cpu_subsystem` registra senales de observabilidad de CPU antes de entregarlas a `debug_unit_top` para ayudar a timing closure. Cuando la debug unit necesita inspeccionar estado, mantiene la CPU detenida mediante `o_cpu_enable`.

## UART

El enlace host-FPGA usa UART 115200 8N1 por defecto.

Flujo RX:

```text
i_uart_rx -> uart_rx -> RX FIFO -> debug_unit_top
```

Flujo TX:

```text
debug_unit_top -> TX FIFO -> uart_tx -> o_uart_tx
```

`debug_unit_top` OR-gatea varias fuentes TX internas. Esto es seguro porque `du_master` asegura exclusion mutua: solo un transmisor de debug esta activo por vez.

## FPGA

La placa objetivo documentada es Nexys 4. El archivo `boards/Nexys-4-Master.xdc` define:

| Puerto | Pin | Uso |
|--------|-----|-----|
| `clock` | `E3` | Clock de placa 100 MHz. |
| `i_rst` | `U9` | Reset fisico activo alto. |
| `i_uart_rx` | `C4` | RX desde USB-UART. |
| `o_uart_tx` | `D4` | TX hacia USB-UART. |
