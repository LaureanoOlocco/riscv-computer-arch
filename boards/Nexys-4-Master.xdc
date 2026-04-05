## Clock signal - 100MHz
set_property PACKAGE_PIN E3 [get_ports clock]
    set_property IOSTANDARD LVCMOS33 [get_ports clock]
    create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clock]
    set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clock_IBUF]

## Reset - SW0 (Nexys4)
set_property PACKAGE_PIN J15 [get_ports i_rst]
    set_property IOSTANDARD LVCMOS33 [get_ports i_rst]

## UART
set_property PACKAGE_PIN C4 [get_ports i_uart_rx]
    set_property IOSTANDARD LVCMOS33 [get_ports i_uart_rx]

set_property PACKAGE_PIN D4 [get_ports o_uart_tx]
    set_property IOSTANDARD LVCMOS33 [get_ports o_uart_tx]

## Configuration
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]