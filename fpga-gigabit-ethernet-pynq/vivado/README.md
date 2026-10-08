# Vivado PL RGMII Reference

This directory preserves the Verilog Ethernet reference design as a separate,
optional PL workstream. It is intended for a compatible external RGMII PHY
connected to PL I/O, not the PYNQ-Z2 onboard Ethernet jack.

## Hardware limitation

The PYNQ-Z2's onboard RTL8211E is connected to the Zynq PS GEM over PS MIO.
Vivado XDC constraints cannot reroute that board-level connection to PL. The
template `constraints/external_rgmii_timing_template.xdc` therefore contains
no `PACKAGE_PIN` assignments and is not sufficient to build a deployable board
image. To use this design, select an external RGMII PHY and PL connector, check
the board schematic and PHY datasheet, then provide verified pin assignments,
I/O standards, clocking, PHY timing, and trace-delay constraints.

The reference files are retained source artifacts, not evidence of successful
synthesis, timing closure, or physical operation. Review and validate them for
the chosen PHY and Vivado version before hardware use.

## Contents

- `rtl/`: CRC-32, RGMII/GMII conversion, ARP reply/cache, UDP/IPv4, packet
  generator, and top-level AXI-stream RTL.
- `constraints/`: external PHY timing template only.
- `sim/`: top-level transaction testbench and CRC comparison testbench.
- `scripts/build_project.tcl`: batch-mode Vivado project and run targets.
- [`../docs/VIVADO_RTL_REFERENCE.md`](../docs/VIVADO_RTL_REFERENCE.md):
  module-level explanation and scope.

## Vivado commands

Run from this directory with Vivado 2022.x or later available on `PATH`:

```sh
vivado -mode batch -source scripts/build_project.tcl -tclargs prepare
vivado -mode batch -source scripts/build_project.tcl -tclargs sim
vivado -mode batch -source scripts/build_project.tcl -tclargs crc_sim
vivado -mode batch -source scripts/build_project.tcl -tclargs synth
vivado -mode batch -source scripts/build_project.tcl -tclargs impl
vivado -mode batch -source scripts/build_project.tcl -tclargs timing
vivado -mode batch -source scripts/build_project.tcl -tclargs bitstream
```

The synthesis, implementation, timing, and bitstream targets use
`xc7z020clg400-1` as the part selection. `prepare` only creates a Vivado
project; the XDC is a starting template and needs the real external PHY pin and
timing data before implementation results can be treated as meaningful.

The testbenches are reference checks, not a replacement for lint, formal
verification, hardware-specific timing analysis, or PHY interoperability
testing.
