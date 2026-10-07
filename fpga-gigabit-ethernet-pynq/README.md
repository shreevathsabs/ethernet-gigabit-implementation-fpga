# PL Ethernet prototype for Zynq-7000

This source tree describes a PL-side 10/100/1000 RGMII MAC/IP/UDP prototype
for `xc7z020clg400-1`. It requires an **external RGMII PHY connected to PL**.
The onboard RTL8211E on a TUL PYNQ-Z2 is wired to the processing-system GEM
through MIO; it is not available as a PL RGMII interface. Consequently this
tree intentionally has no PYNQ-Z2 package-pin assignments and cannot operate
the board's onboard Ethernet connector as a PL-only design.

The XDC contains placeholder-free clocks and illustrative PHY-side timing
values, but it is not a board-verified pinout or timing signoff. Select an
external PHY/connector, consult its data sheet and the actual PCB timing, then
add verified package pins and update input/output delays before implementation.
`rgmii_to_gmii.v` uses 7-series `IDDR` and `ODDR` primitives and requires Vivado
or a simulator configured with the Xilinx UNISIM library.

## RTL interfaces and current behavior

The top receives payload bytes on AXI4-Stream and sends a UDP datagram to the
most recently learned ARP peer, using the configured `UDP_PORT` for both source
and destination ports. ARP requests for `BOARD_IP` are answered automatically.
Received UDP payload is placed in a 2 KiB output FIFO and exposed on the RX
AXI4-Stream interface. The 2 KiB TX buffer accepts a packet at a time; payloads
larger than 1472 bytes are discarded rather than transmitted. Board MAC/IP and
UDP port are Verilog parameters.

This is a bring-up baseline, not a claimed production signoff: it does not
implement PHY management/MDIO, VLAN, IP fragmentation, UDP checksum
verification, retransmission, descriptor DMA, or a verified asynchronous
clock-domain crossing between recovered RGMII RXC and `clk`. Use a common,
phase-controlled 125 MHz design clock only when the external PHY clocking and
timing architecture has been validated. The supplied testbench checks emitted
ARP and UDP frame fields and FCS in Vivado simulation; hardware use requires
board-specific timing closure and system-level interoperability validation.

## Build and test

Run from Vivado 2022.2 or newer:

```text
vivado -mode batch -source scripts/build_project.tcl -tclargs prepare
vivado -mode batch -source scripts/build_project.tcl -tclargs synth
vivado -mode batch -source scripts/build_project.tcl -tclargs impl
vivado -mode batch -source scripts/build_project.tcl -tclargs timing
vivado -mode batch -source scripts/build_project.tcl -tclargs bitstream
vivado -mode batch -source scripts/build_project.tcl -tclargs sim
```

The Python scripts exercise a remote UDP echo endpoint on the FPGA or test
system; this RTL does not itself echo incoming UDP packets.
