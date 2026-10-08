# PYNQ-Z2 PS UDP Performance Comparison

This project compares two UDP echo-server implementations on the PYNQ-Z2 Zynq
Processing System (PS), using its built-in RTL8211E Ethernet PHY and PS GEM
controller:

| Version | Program on the board | Per-packet behavior |
|---|---|---|
| Baseline | `sw/udp_echo_server.py` | Python `recvfrom` and `sendto` for each datagram |
| Candidate | `sw/udp_echo_server_batch.c` | Linux C `recvmmsg` and `sendmmsg`, batching up to 32 datagrams per call |

Both versions are real software running on the board's ARM Cortex-A9 under
Linux. They share the same host benchmark, packet format, payload lengths, and
requested socket-buffer size. The candidate is intended to reduce user/kernel
transitions; actual performance gains must be measured and are not assumed.
This PS-vs-PS project does not include a PL Ethernet data path or Vivado
bitstream.

## Data path

![PYNQ-Z2 PS Ethernet flow](docs/ps_ethernet_flow.svg)

## Project presentation

The literature survey, research gap, methodology, components, toolchain, and
measurement plan are followed by a full PS data-path block diagram and a
complete source-code appendix for all five project software files in
[`docs/PS_UDP_Performance_Comparison.pptx`](docs/PS_UDP_Performance_Comparison.pptx).
The deck source is `docs/generate_presentation.py`. Regenerate it with Python 3
and `python-pptx` installed:

```sh
python docs/generate_presentation.py
```

For a technical walk-through, rehearsal pitch, likely engineer questions, and
benchmark caveats, see
[`docs/ENGINEER_MEETING_STUDY_GUIDE.md`](docs/ENGINEER_MEETING_STUDY_GUIDE.md).

## Run the demo

1. Boot the PYNQ-Z2 with its supported PYNQ Linux image and connect the built-in
   RJ45 jack to the same LAN as the host PC. Connect power and configure the
   board's network using the normal Linux/DHCP setup.
2. Find the board's IP address from the PYNQ console with `hostname -I`.
3. Copy both server implementations to the board:

   ```sh
   scp fpga-gigabit-ethernet-pynq/sw/udp_echo_server.py fpga-gigabit-ethernet-pynq/sw/udp_echo_server_batch.c xilinx@<board-ip>:/home/xilinx/
   ```

4. Start the Python baseline on the board:

   ```sh
   ssh xilinx@<board-ip> "python3 /home/xilinx/udp_echo_server.py --port 5001 --socket-buffer 4194304"
   ```

   Leave it running while testing. Stop it with Ctrl-C; it prints packet and
   byte totals on exit.
5. Run the integrity test against the Python baseline. Stop it with Ctrl-C,
   compile the C candidate on the board, then start the candidate:

   ```sh
   python fpga-gigabit-ethernet-pynq/sw/udp_loopback_test.py --host <board-ip> --port 5001
   ssh xilinx@<board-ip> "gcc -O3 -Wall -Wextra -Werror -std=gnu11 /home/xilinx/udp_echo_server_batch.c -o /home/xilinx/udp_echo_server_batch"
   ssh xilinx@<board-ip> "/home/xilinx/udp_echo_server_batch 5001 4194304"
   ```

6. Run the same integrity test against the C candidate:

   ```sh
   python fpga-gigabit-ethernet-pynq/sw/udp_loopback_test.py --host <board-ip> --port 5001
   ```

7. Measure each version using identical benchmark parameters. Add `--variant`
   and separate JSONL output files so runs are attributable and comparable:

   ```sh
   python fpga-gigabit-ethernet-pynq/sw/throughput_benchmark.py --host <board-ip> --port 5001 --variant python --seconds 10 --length 1472 --burst-size 32 --socket-buffer 4194304 --output python.jsonl
   python fpga-gigabit-ethernet-pynq/sw/throughput_benchmark.py --host <board-ip> --port 5001 --variant c --seconds 10 --length 1472 --burst-size 32 --socket-buffer 4194304 --output c.jsonl
   ```

   Run the Python command only while the Python server is active. Stop it, start
   the C server, and then run the C command. Do not run both servers at once.
   Repeat each run at least five times for payload sizes 64, 512, and 1472
   bytes, alternating which server runs first.
   Keep host, cable/switch, board image, port, packet sizes, socket buffers,
   test duration, and host benchmark process unchanged. Stop one server before
   starting the other; they cannot bind the same port simultaneously.
   The same 32-packet burst is used for both; it gives the batched server an
   opportunity to receive multiple queued datagrams in one system call.

8. Compare the median results:

   ```sh
   python fpga-gigabit-ethernet-pynq/sw/compare_results.py --python python.jsonl --c c.jsonl
   ```

Both client scripts use Python sockets. The benchmark records sent/unique
replies, loss, duplicate/corrupt replies, application goodput, replies/sec, and
mean/p50/p95 round-trip latency. It saves one JSON record per run. The C and
Python servers print handled packet/byte counts and process CPU seconds on
Ctrl-C. Also record CPU usage while running with the same Linux tool (such as
`pidstat` if installed, otherwise `top`) and use Wireshark to check the actual
ARP/UDP traffic. Network goodput includes host, Linux, and application
overhead; it is not a PHY line-rate measurement.

## How to demonstrate an improvement

Use the results table generated by `compare_results.py`, plus repeated raw
JSONL runs and server logs. The C version only supports the claim “better” if
it improves a chosen metric (for example median replies/sec or goodput) while
keeping packet loss and corruption acceptably low. Include latency and CPU use
as tradeoffs. Explain the implementation change—batching Linux UDP calls—and
do not claim a speedup if measurements overlap or are inconclusive.
For the loss row, positive percentage points mean reduced loss; positive
percentages on the other rows indicate improvement.

## Recording validation results

Record board image/kernel, host OS/Python version, network link speed/duplex,
socket-buffer values, test commands, all repeated runs, server CPU summaries,
and Wireshark observations in `results/README.md`. Do not enter expected or
localhost test numbers as board measurements.

Before testing, capture board configuration with `uname -a`,
`cat /etc/os-release`, `gcc --version`, and `getconf LONG_BIT`; record
`ethtool eth0` output too when that utility is installed. This verifies the
Linux/compiler environment and link settings before drawing conclusions.
