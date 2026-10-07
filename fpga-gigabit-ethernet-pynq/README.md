# PYNQ-Z2 Ethernet using the Processing System

This version uses the board's built-in Ethernet jack. The jack's RTL8211E PHY
is connected to the Zynq-7000 Processing System (PS) GEM Ethernet controller.
Linux on the ARM Cortex-A9 runs the Ethernet driver and network stack, and
`sw/udp_echo_server.py` provides a UDP application endpoint. This is real
networking hardware on the board, but it is not a custom PL Ethernet stack.

The main demonstration is PS-based, and Vivado is not needed for that network
path. A separate PL reference implementation is included in `rtl/`, with a
Vivado script, simulation testbench, and pin-agnostic XDC template. This
reference requires an **external RGMII PHY connected to PL**; it cannot use the
built-in jack. Its XDC intentionally contains no invented PYNQ-Z2 package-pin
assignments. The RTL is provided as a separate learning/reference path and has
not been verified as production-ready or validated on the board.

Using PL to process traffic from the PS GEM would require a separate AXI/DMA
datapath and is outside the PS demo's current scope.

## Data path

![PYNQ-Z2 PS Ethernet flow](docs/ps_ethernet_flow.svg)

## Run the demo

1. Boot the PYNQ-Z2 with its supported PYNQ Linux image and connect the built-in
   RJ45 jack to the same LAN as the host PC. Connect power and configure the
   board's network using the normal Linux/DHCP setup.
2. Find the board's IP address from the PYNQ console with `hostname -I`.
3. Copy `sw/udp_echo_server.py` to the board, for example:

   ```sh
   scp fpga-gigabit-ethernet-pynq/sw/udp_echo_server.py xilinx@<board-ip>:/home/xilinx/
   ```

4. Start the echo service on the board:

   ```sh
   ssh xilinx@<board-ip> "python3 /home/xilinx/udp_echo_server.py --port 5001"
   ```

   Leave it running while testing. Stop it with Ctrl-C; it prints packet and
   byte totals on exit.
5. From the host PC, run the integrity test:

   ```sh
   python fpga-gigabit-ethernet-pynq/sw/udp_loopback_test.py --host <board-ip> --port 5001
   ```

6. Measure received application goodput:

   ```sh
   python fpga-gigabit-ethernet-pynq/sw/throughput_benchmark.py --host <board-ip> --port 5001 --seconds 5 --length 1472
   ```

Both test scripts use standard Python sockets. The throughput result includes
host, Linux, and UDP echo application overhead; it is not a PHY line-rate
measurement. Run Wireshark on the host's Ethernet interface to inspect ARP and
UDP packets. ARP is handled by Linux and the PS GEM driver, not custom PL RTL.

## Vivado's role

For the selected PS networking demonstration, Vivado is not used to create an
Ethernet bitstream. Use the board's PYNQ image and Linux networking tools.
The optional PL reference can be opened with
`vivado -mode batch -source scripts/build_project.tcl -tclargs sim` from
`fpga-gigabit-ethernet-pynq/`; synthesis and implementation require a real
external-PHY board pinout and validated timing constraints before they are
meaningful. Programming PL over JTAG does not route the built-in Ethernet
traffic into PL.

## Recording validation results

After tests have actually run, record date, board image, host OS/Python version,
board IP setup, commands, packet count, byte count, loss, and measured goodput
in `results/README.md`. Attach Wireshark captures or screenshots when useful.
Do not enter expected/example numbers as measured results.
