## Clock signal - 100MHz
set_property PACKAGE_PIN E3 [get_ports clock]
set_property IOSTANDARD LVCMOS33 [get_ports clock]

# Removed -add flag: using -add left the MMCM IP's auto-generated "clock"
# definition coexisting with "sys_clk_pin" on the same port, causing 2711
# registers to appear with multiple_clock and triggering TIMING-6.
# A single definition here overrides any IP-generated create_clock.
create_clock -name sys_clk_pin -period 10.000 -waveform {0 5.000} [get_ports clock]

# TIMING-56: the MMCM generates two logical names from the same output pin
# (clk_out1_clk_wiz_0 / clk_out1_clk_wiz_0_1 and their feedback copies).
# Declare them physically exclusive so STA does not analyze cross-domain
# paths between names that share the same physical net.
set_clock_groups -physically_exclusive \
    -group [get_clocks clk_out1_clk_wiz_0] \
    -group [get_clocks clk_out1_clk_wiz_0_1]

set_clock_groups -physically_exclusive \
    -group [get_clocks clkfbout_clk_wiz_0] \
    -group [get_clocks clkfbout_clk_wiz_0_1]

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_inst/inst/clk_in1_clk_wiz_0]

## Reset - BTN0 (boton izquierdo)
set_property PACKAGE_PIN U9 [get_ports i_rst]
set_property IOSTANDARD LVCMOS33 [get_ports i_rst]
set_false_path -from [get_ports i_rst]

## UART - USB-UART (chip FT2232)
set_property PACKAGE_PIN C4 [get_ports i_uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports i_uart_rx]
set_property PACKAGE_PIN D4 [get_ports o_uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports o_uart_tx]
set_false_path -from [get_ports i_uart_rx]
set_false_path -to [get_ports o_uart_tx]

## Configuration
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]