# Arty A7-35 Rev. D/E, from Digilent's Arty-A7-35-Master.xdc:
# https://github.com/Digilent/digilent-xdc/blob/master/Arty-A7-35-Master.xdc
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -name sys_clk -period 10.000 [get_ports clk]
# BTN0 is active high; RTL synchronizes button assertion and release.
set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS33} [get_ports reset]
set_false_path -from [get_ports reset] -to [get_cells -hier -filter {NAME =~ *reset_sync_reg*}]
# Low nibble: four discrete green LEDs.
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} [get_ports {leds[0]}]
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} [get_ports {leds[1]}]
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports {leds[2]}]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {leds[3]}]
# High nibble: green channels of the four RGB LEDs.
set_property -dict {PACKAGE_PIN F6 IOSTANDARD LVCMOS33} [get_ports {leds[4]}]
set_property -dict {PACKAGE_PIN J4 IOSTANDARD LVCMOS33} [get_ports {leds[5]}]
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33} [get_ports {leds[6]}]
set_property -dict {PACKAGE_PIN H6 IOSTANDARD LVCMOS33} [get_ports {leds[7]}]
set_property -dict {PACKAGE_PIN G6 IOSTANDARD LVCMOS33} [get_ports halted]
# LEDs are human-visible indicators with no external synchronous receiver.
set_false_path -to [get_ports {leds[*] halted}]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
# USB-UART names in the master XDC are from the bridge/host perspective:
# UART_TXD_IN (A9) is FPGA RX; UART_RXD_OUT (D10) is FPGA TX.
# Direction cross-check: LiteX-Boards digilent_arty.py serial rx=A9, tx=D10.
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS33} [get_ports uart_rx]
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports uart_tx]
set_false_path -from [get_ports uart_rx] -to [get_cells -hier -filter {NAME =~ *rx_sync_reg*}]
set_false_path -to [get_ports uart_tx]
