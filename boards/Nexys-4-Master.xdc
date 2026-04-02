## Nexys 4 DDR - Constraints for RISC-V CPU
## Port names match top.v: clk, i_rst, o_uart_tx, i_uart_rx

## Clock signal
##Bank = 35, Pin name = IO_L12P_T1_MRCC_35, Sch name = CLK100MHZ
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Switches
##Bank = 34, Pin name = IO_L21P_T3_DQS_34, Sch name = SW0
set_property PACKAGE_PIN U9 [get_ports i_rst]
set_property IOSTANDARD LVCMOS33 [get_ports i_rst]

## USB-RS232 Interface
##Bank = 35, Pin name = IO_L7P_T1_AD6P_35, Sch name = UART_TXD_IN (host TX -> FPGA RX)
set_property PACKAGE_PIN C4 [get_ports i_uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports i_uart_rx]

##Bank = 35, Pin name = IO_L11N_T1_SRCC_35, Sch name = UART_RXD_OUT (FPGA TX -> host RX)
set_property PACKAGE_PIN D4 [get_ports o_uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports o_uart_tx]

## Configuration options
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## SPI configuration mode options for QSPI boot
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
