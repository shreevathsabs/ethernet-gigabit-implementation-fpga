# Validation results

Add measured results here after testing on a PYNQ-Z2. No board or Vivado
measurements have been recorded yet.

Record at least:

- Test date and PYNQ image/version
- Host operating system and Python version
- Network topology and link speed/duplex
- UDP loopback command, payload length, packets sent/verified
- Throughput command, duration, sent/received/lost packets, measured goodput
- Wireshark observations or capture filename
- Any errors, configuration changes, or repeatability notes

For the PL CRC baseline-versus-parallel experiment, also record:

- Vivado version, FPGA part, and synthesis strategy
- Clock constraint and the reported worst register-to-register delay
- LUT and flip-flop utilization for each separately synthesized CRC module
- CRC simulation result and report/log file locations
- Whether each implementation meets the same target clock

Do not describe the parallel XOR implementation as an improvement unless
identical Vivado runs show a measurable benefit without changing CRC behavior.
