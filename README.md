# ethernet-gigabit-implementation-fpga

PL-side Ethernet RTL sources and build instructions are in
[`fpga-gigabit-ethernet-pynq/`](fpga-gigabit-ethernet-pynq/README.md).

The PYNQ-Z2 onboard Ethernet PHY is connected to the Zynq processing system
through MIO, not to PL RGMII pins. The PL RTL therefore requires an external
RGMII PHY connected to PL; the included XDC deliberately does not invent
PYNQ-Z2 package-pin assignments.
