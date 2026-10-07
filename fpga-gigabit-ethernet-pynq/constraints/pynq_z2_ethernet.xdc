# Pin-agnostic RGMII timing template for an external PHY wired to PL.
# The PYNQ-Z2 onboard RTL8211E is connected to PS MIO, not PL RGMII pins.
# Assign PACKAGE_PIN values only after selecting a PL connector and confirming
# the board/PHY schematic and PCB trace delays.

create_clock -name sys_clk_125 -period 8.000 [get_ports clk]
create_clock -name rgmii_rxc_125 -period 8.000 [get_ports rgmii_rxc]
create_generated_clock -name rgmii_txc_125 -source [get_ports clk] \
    -divide_by 1 [get_ports rgmii_txc]

set_property IOSTANDARD LVCMOS33 [get_ports {rgmii_rxc rgmii_rxd[*] rgmii_rx_ctl \
    rgmii_txc rgmii_txd[*] rgmii_tx_ctl}]
set_property SLEW FAST [get_ports {rgmii_txc rgmii_txd[*] rgmii_tx_ctl}]

# Replace these PHY-side timing values with the actual PHY datasheet values
# plus/minus board trace skew. Values below are a conservative starting point,
# not a claim of PYNQ-Z2 connector timing closure.
set_input_delay -clock rgmii_rxc_125 -max 2.000 \
    [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
set_input_delay -clock rgmii_rxc_125 -min 0.000 \
    [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
set_input_delay -clock rgmii_rxc_125 -clock_fall -add_delay -max 2.000 \
    [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]
set_input_delay -clock rgmii_rxc_125 -clock_fall -add_delay -min 0.000 \
    [get_ports {rgmii_rxd[*] rgmii_rx_ctl}]

set_output_delay -clock rgmii_txc_125 -max 1.000 \
    [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
set_output_delay -clock rgmii_txc_125 -min -1.000 \
    [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
set_output_delay -clock rgmii_txc_125 -clock_fall -add_delay -max 1.000 \
    [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
set_output_delay -clock rgmii_txc_125 -clock_fall -add_delay -min -1.000 \
    [get_ports {rgmii_txd[*] rgmii_tx_ctl}]
