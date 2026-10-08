# Vivado RTL Reference Guide

The files under `vivado/rtl/` represent a PL-based Ethernet datapath
exploration. The existing PYNQ-Z2 RJ45 does not connect to PL, so these modules
need an external RGMII PHY and verified PL connector pinout to operate on
hardware. Module presence is not a claim of production readiness or timing
closure.

| Module | Role |
|---|---|
| `rgmii_to_gmii.v` | Converts RGMII DDR signals to GMII-style byte signals and back |
| `crc32_d8.v` | Byte-parallel Ethernet CRC-32/FCS calculation |
| `crc32_d8_parallel.v` | Alternate CRC implementation used by the comparison testbench |
| `arp_cache_engine.v` | ARP request handling, reply generation, and peer MAC/IP caching |
| `udp_ip_tx.v` | Ethernet/IPv4/UDP transmit frame construction |
| `udp_ip_rx.v` | IPv4/UDP receive parsing and payload output |
| `axis_packet_generator.v` | AXI4-Stream payload pattern source |
| `mac_ip_udp_axis_top.v` | Top-level integration and transmit arbitration |

`sim/tb_mac_ip_udp.v` drives an RGMII-side transaction and checks the reference
top-level behavior. `sim/tb_crc32_compare.v` compares the two CRC modules.
Review the testbench coverage against the required behavior before relying on
it as verification.

The XDC file is deliberately named
`vivado/constraints/external_rgmii_timing_template.xdc`. It contains example
clock and I/O timing constraints but no pin locations. Replace example timing
values with the selected PHY's datasheet values, account for PCB trace delays
and skew, and add actual pin/IOSTANDARD assignments only after confirming the
target board schematic.
