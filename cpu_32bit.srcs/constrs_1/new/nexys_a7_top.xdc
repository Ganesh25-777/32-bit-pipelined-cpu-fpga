## ==========================================
## Nexys A7-100T FPGA Pin Constraints
## Top module: nexys_a7_top
## ==========================================

## 100 MHz onboard clock
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { clk }]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5} [get_ports { clk }]

## ==========================================
## USB-UART (Nexys A7 onboard USB-UART bridge)
## PC -> FPGA: FPGA receives on C4
## FPGA -> PC: FPGA transmits on D4
## ==========================================
set_property -dict { PACKAGE_PIN C4 IOSTANDARD LVCMOS33 } [get_ports { uart_rx_pin }]
set_property -dict { PACKAGE_PIN D4 IOSTANDARD LVCMOS33 } [get_ports { uart_tx_pin }]

## ==========================================
## CPU_RESETN pushbutton (active-low), pin C12
## Top module uses resetn and inverts it for active-high CPU reset.
## ==========================================
set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports { resetn }]
