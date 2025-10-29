## This file is a general .xdc for the Nexys4 rev B board
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project

## Clock signal
##Bank = 35, Pin name = IO_L12P_T1_MRCC_35, Sch name = CLK100MHZ
set_property PACKAGE_PIN E3 [get_ports clock]
set_property IOSTANDARD LVCMOS33 [get_ports clock]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clock]

## Override clock routing constraint to allow synthesis to complete
# set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clock_IBUF]

## Switches
##Bank = 34, Pin name = IO_L21P_T3_DQS_34, Sch name = SW0
set_property PACKAGE_PIN U9 [get_ports i_rst]
set_property IOSTANDARD LVCMOS33 [get_ports i_rst]

##Pmod Header JA
##Bank = 15, Pin name = IO_L1N_T0_AD0N_15, Sch name = JA1
set_property PACKAGE_PIN B13 [get_ports {o_uart[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_uart[0]}]

##Bank = 15, Pin name = IO_L5N_T0_AD9N_15, Sch name = JA2
set_property PACKAGE_PIN F14 [get_ports {o_uart[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_uart[1]}]

##USB-RS232 Interface
##Bank = 35, Pin name = IO_L7P_T1_AD6P_35, Sch name = UART_TXD_IN
set_property PACKAGE_PIN C4 [get_ports i_rx]
set_property IOSTANDARD LVCMOS33 [get_ports i_rx]

##Bank = 35, Pin name = IO_L11N_T1_SRCC_35, Sch name = UART_RXD_OUT
set_property PACKAGE_PIN D4 [get_ports i_tx]
set_property IOSTANDARD LVCMOS33 [get_ports i_tx]

## Configuration options, can be used for all designs
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## SPI configuration mode options for QSPI boot, can be used for all designs
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
