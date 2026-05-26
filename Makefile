BUILD_DIR := build
ASM_DIR   := code/asm
BIN_DIR   := code/bin

IVERILOG := iverilog
VVP      := vvp
PYTHON   := python3
IVFLAGS  := -g2012

# ── RTL source groups ─────────────────────────────────────────────────────────
CPU_ALU      := modules/cpu/alu/rtl/alu.v
CPU_ADDER    := modules/cpu/adder/rtl/adder.v
CPU_CTRL     := modules/cpu/control/rtl/alu_control_unit.v \
                modules/cpu/control/rtl/base_integer_ctrl_unit.v \
                modules/cpu/control/rtl/immediate_generator.v \
                modules/cpu/control/rtl/jump_ctrl_unit.v
CPU_MUX      := modules/cpu/muxes/rtl/mux2to1.v \
                modules/cpu/muxes/rtl/mux3to1.v \
                modules/cpu/muxes/rtl/mux4to1.v
CPU_MEM      := modules/cpu/memory/rtl/block_ram.v \
                modules/cpu/memory/rtl/data_mem_output_unit.v
CPU_PC       := modules/cpu/pc/rtl/pc.v
CPU_REGFILE  := modules/cpu/regfile/rtl/regfile.v
CPU_PIPELINE := modules/cpu/pipeline/rtl/ex_mem_reg.v \
                modules/cpu/pipeline/rtl/id_ex_reg.v \
                modules/cpu/pipeline/rtl/if_id_reg.v \
                modules/cpu/pipeline/rtl/mem_wb_reg.v
CPU_HAZARD   := modules/cpu/hazard/rtl/ex_forwarding_unit.v \
                modules/cpu/hazard/rtl/hazard_detection_unit.v \
                modules/cpu/hazard/rtl/id_forwarding_unit.v \
                modules/cpu/hazard/rtl/jump_hazard_detection_unit.v \
                modules/cpu/hazard/rtl/mem_forward_unit.v

UART_CORE    := modules/uart/core/rtl/uart_tx.v \
                modules/uart/core/rtl/uart_rx.v
UART_SUPPORT := modules/uart/support/rtl/baud_rate_gen.v \
                modules/uart/support/rtl/interface.v
UART_FIFO    := modules/uart/buffering/rtl/fifo.v
UART_TOP     := modules/uart/top/rtl/top_uart.v \
                $(UART_CORE) $(UART_SUPPORT) $(UART_FIFO)

DU_COMM      := modules/debug_unit/communication/rtl/du_latch_tx.v \
                modules/debug_unit/communication/rtl/du_master.v \
                modules/debug_unit/communication/rtl/du_resp_builder.v
DU_CTRL      := modules/debug_unit/control/rtl/du_breakpoint.v
DU_MEM       := modules/debug_unit/memory/rtl/du_dmem_rx.v \
                modules/debug_unit/memory/rtl/du_dmem_tx.v \
                modules/debug_unit/memory/rtl/du_imem_loader.v
DU_REGFILE   := modules/debug_unit/regfile/rtl/du_regfile_rx.v \
                modules/debug_unit/regfile/rtl/du_regfile_tx.v
DU_TOP       := modules/debug_unit/top/rtl/debug_unit_top.v \
                $(DU_COMM) $(DU_CTRL) $(DU_MEM) $(DU_REGFILE)

# ── Testbench lists ───────────────────────────────────────────────────────────
CPU_TESTS := \
    $(BUILD_DIR)/alu_tb.vvp \
    $(BUILD_DIR)/adder_tb.vvp \
    $(BUILD_DIR)/alu_ctrl_unit_tb.vvp \
    $(BUILD_DIR)/base_integer_ctrl_unit_tb.vvp \
    $(BUILD_DIR)/jump_ctrl_unit_tb.vvp \
    $(BUILD_DIR)/mux2to1_tb.vvp \
    $(BUILD_DIR)/mux3to1_tb.vvp \
    $(BUILD_DIR)/mux4to1_tb.vvp \
    $(BUILD_DIR)/ex_forwarding_unit_tb.vvp \
    $(BUILD_DIR)/hazard_detection_unit_tb.vvp \
    $(BUILD_DIR)/id_forwarding_unit_tb.vvp \
    $(BUILD_DIR)/jump_hazard_detection_unit_tb.vvp \
    $(BUILD_DIR)/mem_forwarding_unit_tb.vvp

UART_TESTS := \
    $(BUILD_DIR)/uart_tx_tb.vvp \
    $(BUILD_DIR)/uart_rx_tb.vvp \
    $(BUILD_DIR)/baud_rate_gen_tb.vvp \
    $(BUILD_DIR)/interface_tb.vvp \
    $(BUILD_DIR)/fifo_tb.vvp \
    $(BUILD_DIR)/top_uart_tb.vvp

DU_TESTS := \
    $(BUILD_DIR)/tb_du_latch_tx.vvp \
    $(BUILD_DIR)/tb_du_master.vvp \
    $(BUILD_DIR)/tb_du_resp_builder.vvp \
    $(BUILD_DIR)/tb_du_breakpoint.vvp \
    $(BUILD_DIR)/tb_du_dmem_rx.vvp \
    $(BUILD_DIR)/tb_du_regfile_rx.vvp \
    $(BUILD_DIR)/tb_du_regfile_tx.vvp \
    $(BUILD_DIR)/tb_debug_unit_top.vvp

ALL_TESTS := $(CPU_TESTS) $(UART_TESTS) $(DU_TESTS)

# ── Default ───────────────────────────────────────────────────────────────────
.PHONY: all
all: help

# ── Help ──────────────────────────────────────────────────────────────────────
.PHONY: help
help:
	@echo "Targets:"
	@echo "  sim-all                  Compile and run every testbench"
	@echo "  sim-cpu                  Compile and run CPU testbenches"
	@echo "  sim-uart                 Compile and run UART testbenches"
	@echo "  sim-du                   Compile and run Debug Unit testbenches"
	@echo "  sim-<name>               Compile and run one testbench (e.g. sim-alu_tb)"
	@echo "  asm SRC=<name>           Assemble code/asm/<name>.s → code/bin/<name>.bin"
	@echo "  asm-all                  Assemble all .s files in code/asm/"
	@echo "  clean                    Remove $(BUILD_DIR)/"

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# ── CPU testbenches ───────────────────────────────────────────────────────────
$(BUILD_DIR)/alu_tb.vvp: modules/cpu/alu/tests/alu_tb.sv $(CPU_ALU) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/adder_tb.vvp: modules/cpu/adder/tests/adder_tb.sv $(CPU_ADDER) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/alu_ctrl_unit_tb.vvp: modules/cpu/control/tests/alu_ctrl_unit_tb.sv modules/cpu/control/rtl/alu_control_unit.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/base_integer_ctrl_unit_tb.vvp: modules/cpu/control/tests/base_integer_ctrl_unit_tb.sv modules/cpu/control/rtl/base_integer_ctrl_unit.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/jump_ctrl_unit_tb.vvp: modules/cpu/control/tests/jump_ctrl_unit_tb.sv modules/cpu/control/rtl/jump_ctrl_unit.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/mux2to1_tb.vvp: modules/cpu/muxes/tests/mux2to1_tb.sv modules/cpu/muxes/rtl/mux2to1.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/mux3to1_tb.vvp: modules/cpu/muxes/tests/mux3to1_tb.sv modules/cpu/muxes/rtl/mux3to1.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/mux4to1_tb.vvp: modules/cpu/muxes/tests/mux4to1_tb.sv modules/cpu/muxes/rtl/mux4to1.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/ex_forwarding_unit_tb.vvp: modules/cpu/hazard/tests/ex_forwarding_unit_tb.sv modules/cpu/hazard/rtl/ex_forwarding_unit.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/hazard_detection_unit_tb.vvp: modules/cpu/hazard/tests/hazard_detection_unit_tb.sv modules/cpu/hazard/rtl/hazard_detection_unit.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/id_forwarding_unit_tb.vvp: modules/cpu/hazard/tests/id_forwarding_unit_tb.sv modules/cpu/hazard/rtl/id_forwarding_unit.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/jump_hazard_detection_unit_tb.vvp: modules/cpu/hazard/tests/jump_hazard_detection_unit_tb.sv modules/cpu/hazard/rtl/jump_hazard_detection_unit.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/mem_forwarding_unit_tb.vvp: modules/cpu/hazard/tests/mem_forwarding_unit_tb.sv modules/cpu/hazard/rtl/mem_forward_unit.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

# ── UART testbenches ──────────────────────────────────────────────────────────
$(BUILD_DIR)/uart_tx_tb.vvp: modules/uart/core/tests/uart_tx_tb.sv modules/uart/core/rtl/uart_tx.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/uart_rx_tb.vvp: modules/uart/core/tests/uart_rx_tb.sv modules/uart/core/rtl/uart_rx.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/baud_rate_gen_tb.vvp: modules/uart/support/tests/baud_rate_gen_tb.sv modules/uart/support/rtl/baud_rate_gen.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/interface_tb.vvp: modules/uart/support/tests/interface_tb.sv modules/uart/support/rtl/interface.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/fifo_tb.vvp: modules/uart/buffering/tests/fifo_tb.sv modules/uart/buffering/rtl/fifo.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/top_uart_tb.vvp: modules/uart/top/tests/top_uart_tb.sv $(UART_TOP) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

# ── Debug Unit testbenches ────────────────────────────────────────────────────
$(BUILD_DIR)/tb_du_latch_tx.vvp: modules/debug_unit/communication/tests/tb_du_latch_tx.v modules/debug_unit/communication/rtl/du_latch_tx.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/tb_du_master.vvp: modules/debug_unit/communication/tests/tb_du_master.v $(DU_COMM) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/tb_du_resp_builder.vvp: modules/debug_unit/communication/tests/tb_du_resp_builder.v modules/debug_unit/communication/rtl/du_resp_builder.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/tb_du_breakpoint.vvp: modules/debug_unit/control/tests/tb_du_breakpoint.v $(DU_CTRL) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/tb_du_dmem_rx.vvp: modules/debug_unit/memory/tests/tb_du_dmem_rx.v modules/debug_unit/memory/rtl/du_dmem_rx.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/tb_du_regfile_rx.vvp: modules/debug_unit/regfile/tests/tb_du_regfile_rx.v modules/debug_unit/regfile/rtl/du_regfile_rx.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/tb_du_regfile_tx.vvp: modules/debug_unit/regfile/tests/tb_du_regfile_tx.v modules/debug_unit/regfile/rtl/du_regfile_tx.v | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

$(BUILD_DIR)/tb_debug_unit_top.vvp: modules/debug_unit/top/tests/tb_debug_unit_top.v $(DU_TOP) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $^

# ── Aggregate simulation targets ──────────────────────────────────────────────
.PHONY: sim-all sim-cpu sim-uart sim-du

sim-cpu: $(CPU_TESTS)
	@for f in $^; do echo "=== $$f ==="; $(VVP) $$f; done

sim-uart: $(UART_TESTS)
	@for f in $^; do echo "=== $$f ==="; $(VVP) $$f; done

sim-du: $(DU_TESTS)
	@for f in $^; do echo "=== $$f ==="; $(VVP) $$f; done

sim-all: $(ALL_TESTS)
	@for f in $^; do echo "=== $$f ==="; $(VVP) $$f; done

sim-%: $(BUILD_DIR)/%.vvp
	$(VVP) $<

# ── Assembly ──────────────────────────────────────────────────────────────────
.PHONY: asm asm-all

asm:
ifndef SRC
	$(error SRC is not set. Usage: make asm SRC=test_program)
endif
	$(PYTHON) scripts/parser.py $(ASM_DIR)/$(SRC).s $(BIN_DIR)/$(SRC).bin -v

asm-all:
	@for f in $(ASM_DIR)/*.s; do \
		name=$$(basename $$f .s); \
		echo "=== Assembling $$name ==="; \
		$(PYTHON) scripts/parser.py $$f $(BIN_DIR)/$$name.bin -v; \
	done

# ── Clean ─────────────────────────────────────────────────────────────────────
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
