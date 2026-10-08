# PYNQ-Z2 Ethernet Project

This repository contains two distinct deliverables:

1. **PS-vs-PS UDP performance experiment** — the active PYNQ-Z2 demonstration.
   It compares a Python UDP echo server with a Linux C server using batched
   socket calls, both through the board's built-in Ethernet jack.
2. **Vivado PL RGMII reference** — retained RTL, constraints, testbenches, and
   a build script for an external RGMII PHY connected to PL. It is not wired
   to the PYNQ-Z2 onboard Ethernet jack.

The PYNQ-Z2's RTL8211E PHY connects to the Zynq PS GEM through PS MIO.
Assigning PL package pins cannot redirect that onboard connection. The PL
reference XDC intentionally has no board PACKAGE_PIN assignments. Do not
describe its example constraints as a PYNQ-Z2 onboard Ethernet implementation
or as timing-closed hardware.

## Repository map

| Path | Contents |
|---|---|
| `vivado/rtl/` | Verilog RGMII/GMII, ARP, IPv4/UDP, CRC, and AXI stream reference RTL |
| `vivado/constraints/` | External-PHY RGMII timing template; board-specific pins and PHY timing must be supplied |
| `vivado/sim/` | RTL testbenches |
| `vivado/scripts/` | Vivado project setup, simulation, synthesis, implementation, and bitstream targets |
| `vivado/README.md` | Vivado flow, prerequisites, scope, and limitations |
| `vitis/c/` | Linux C batched UDP echo server and run instructions |
| `vitis/python/board/` | Python UDP echo server to run on PYNQ Linux |
| `vitis/python/host/` | Host-side loopback, benchmark, and comparison tools |
| `vitis/README.md` | How the C and Python sections relate to Vitis and PYNQ Linux |
| `docs/` | Architecture diagram and engineer preparation guide |
| `results/README.md` | Board-measurement record template; no board results are claimed |

## PS-vs-PS experiment

Both implementations run as Linux applications on the Zynq ARM processing
system and use the same PS GEM Ethernet path. The Python baseline uses one
`recvfrom`/`sendto` pair per datagram. The C candidate uses Linux
`recvmmsg`/`sendmmsg` calls with a maximum batch capacity of 32 datagrams.
Batching is a hypothesis for reducing per-packet overhead, not a proven speedup.

![PYNQ-Z2 PS Ethernet flow](docs/ps_ethernet_flow.svg)

See [`vitis/README.md`](vitis/README.md) for the execution setup and commands,
[`results/README.md`](results/README.md) for the measurement template, and
[`docs/ENGINEER_MEETING_STUDY_GUIDE.md`](docs/ENGINEER_MEETING_STUDY_GUIDE.md)
for the project explanation, methodology, and likely technical questions.

## Vivado reference

The PL files are preserved for an external PHY/connector design, not for the
onboard RJ45. See [`vivado/README.md`](vivado/README.md) before using the
template. The source and testbench have not been verified with Vivado in this
environment; no synthesis, timing-closure, or board-operation claim is made.
