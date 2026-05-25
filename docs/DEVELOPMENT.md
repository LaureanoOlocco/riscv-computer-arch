# Development, Simulation, and FPGA

This document describes the practical workflow for working with the project.

## Repository Conventions

Modules usually follow this structure:

```text
modules/<subsystem>/<component>/rtl/
modules/<subsystem>/<component>/tests/
modules/<subsystem>/<component>/docs/
```

Exceptions:

- `modules/top/` contains top-level integration directly.
- `modules/cpu/hazard/rtl/cpu_core.v` contains the full integrated core.
- `boards/` contains FPGA constraints.
- `scripts/` contains host-side tools.

## Assemble Firmware

The simple assembler is `scripts/parser.py`. It supports a subset of RV32I, labels, comments, and ABI register names.

Example:

```bash
python3 scripts/parser.py code/asm/test_program.s code/bin/test_program.bin -v
```

The resulting binary contains little-endian 32-bit instructions, ready to be loaded through the UART debug unit.

## Use the Debug Shell

Install the Python dependency:

```bash
python3 -m pip install pyserial
```

Open the shell:

```bash
python3 scripts/debug_client.py /dev/ttyUSB0 115200
```

Typical flow:

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

Notes:

- `load` appends `0x1A1A1A1A` by default as a halt instruction.
- `rr 255` dumps PC + all 32 registers.
- `wr` and `wm` appear in the help text but are not supported by the current CPU integration.

## Simulate Modules

There is no global runner. Compile each testbench with its RTL dependencies.

ALU example:

```bash
mkdir -p build
iverilog -g2012 -o build/alu_tb.vvp modules/cpu/alu/rtl/alu.v modules/cpu/alu/tests/alu_tb.sv
vvp build/alu_tb.vvp
```

UART TX example:

```bash
mkdir -p build
iverilog -g2012 -o build/uart_tx_tb.vvp modules/uart/core/rtl/uart_tx.v modules/uart/core/tests/uart_tx_tb.sv
vvp build/uart_tx_tb.vvp
```

For integrated testbenches, include every RTL file instantiated by the DUT. If an `Unknown module type` error appears, an RTL dependency is missing from the compilation command.

## Add or Modify a Module

Recommended checklist:

1. Keep the module synthesizable and parameterizable when applicable.
2. Add or update a testbench under `tests/`.
3. Add or update documentation under `docs/` with description, parameters, ports, and behavior.
4. Verify that the testbench compiles with `iverilog -g2012` or the simulator used by the team.
5. If the change affects top-level integration, review `modules/top/top.v`, `modules/top/cpu_subsystem.v`, and `modules/top/top_wrapper.v`.

## FPGA with Vivado

Board top-level:

```text
modules/top/top_wrapper.v
```

Constraints:

```text
boards/Nexys-4-Master.xdc
```

Important points:

- Generate the `clk_wiz_0` IP in Vivado.
- Configure `clk_wiz_0` with a 100 MHz input and a 75 MHz output.
- Add all RTL files under `modules/` to the Vivado project.
- Set `top_wrapper` as the top module.
- Use the `clock`, `i_rst`, `i_uart_rx`, and `o_uart_tx` ports defined in the XDC.

After programming the FPGA:

1. Release the physical reset.
2. Open the serial port at 115200 baud.
3. Run `sync` from `scripts/debug_client.py`.
4. Load firmware and control the CPU from the shell.

## Per-Module Documentation

Existing documentation covers the main blocks:

- CPU: `modules/cpu/**/docs/*.md`.
- UART: `modules/uart/**/docs/*.md`.
- Debug unit: `modules/debug_unit/**/docs/*.md`.

When adding a new module, follow the format used in those guides: title, project/authors/date, description, parameters, ports, behavior, FSM when applicable, and design notes.
