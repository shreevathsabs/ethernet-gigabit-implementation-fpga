# PYNQ-Z2 Gigabit Ethernet Demonstration

This project uses the PYNQ-Z2's built-in Ethernet jack through the Zynq
Processing System (PS) GEM controller. The ARM Cortex-A9 runs Linux and a
Python UDP echo application; test clients run on a host PC. Ethernet traffic
does not pass through custom Programmable Logic (PL) MAC or RGMII RTL.

See [`fpga-gigabit-ethernet-pynq/README.md`](fpga-gigabit-ethernet-pynq/README.md)
for setup, execution, and validation instructions. The revised architecture
diagram is
[`fpga-gigabit-ethernet-pynq/docs/ps_ethernet_flow.svg`](fpga-gigabit-ethernet-pynq/docs/ps_ethernet_flow.svg).

The repository also includes a separate PL RGMII RTL reference under
`fpga-gigabit-ethernet-pynq/rtl/`. It requires an external PHY connected to PL;
it does not connect to the PYNQ-Z2's built-in Ethernet jack.
