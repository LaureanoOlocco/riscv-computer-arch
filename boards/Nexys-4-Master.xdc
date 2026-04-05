## Clock signal - 100MHz
set_property PACKAGE_PIN E3 [get_ports clock]
set_property IOSTANDARD LVCMOS33 [get_ports clock]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5.000} [get_ports clock]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_inst/inst/clk_in1_clk_wiz_0]

## Reset - BTN0 (boton izquierdo)
set_property PACKAGE_PIN D9 [get_ports i_rst]
set_property IOSTANDARD LVCMOS33 [get_ports i_rst]
set_false_path -from [get_ports i_rst]

## UART - USB-UART (chip FT2232)
set_property PACKAGE_PIN A9 [get_ports i_uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports i_uart_rx]
set_property PACKAGE_PIN D10 [get_ports o_uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports o_uart_tx]
set_false_path -from [get_ports i_uart_rx]
set_false_path -to [get_ports o_uart_tx]

## Configuration
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]