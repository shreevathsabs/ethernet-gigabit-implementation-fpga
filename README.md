# PYNQ-Z2 PS UDP Performance Comparison

This project compares two UDP echo-server implementations running on the
PYNQ-Z2 Zynq Processing System (PS): a Python baseline and a candidate Linux C
server using batched UDP socket system calls. Both use the same built-in
Ethernet jack, PS GEM controller, host benchmark, and test settings. The C
version is only considered better if board measurements show an improvement.

See [`fpga-gigabit-ethernet-pynq/README.md`](fpga-gigabit-ethernet-pynq/README.md)
for setup, execution, and evidence-based comparison instructions. The
architecture diagram is
[`fpga-gigabit-ethernet-pynq/docs/ps_ethernet_flow.svg`](fpga-gigabit-ethernet-pynq/docs/ps_ethernet_flow.svg).
