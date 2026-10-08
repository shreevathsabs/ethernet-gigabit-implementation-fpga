# Python UDP Test Tools

Python is used in two different places:

- `board/udp_echo_server.py` runs on PYNQ Linux as the per-datagram baseline.
- `host/` tools run on the PC to test and measure either server.

These scripts are ordinary Python programs, not Vitis applications.

## Board server

Copy `board/udp_echo_server.py` to the PYNQ-Z2 and start it with:

```sh
python3 udp_echo_server.py --port 5001 --socket-buffer 4194304
```

Stop it with Ctrl-C before starting the C server on the same port.

## Host tools

Use Python 3 on the host. From the repository root, first check data integrity:

```sh
python vitis/python/host/udp_loopback_test.py --host <board-ip> --port 5001
```

Run the same benchmark configuration for each server and save separate result
files:

```sh
python vitis/python/host/throughput_benchmark.py --host <board-ip> --port 5001 --variant python --seconds 10 --length 1472 --burst-size 32 --socket-buffer 4194304 --output python.jsonl
python vitis/python/host/throughput_benchmark.py --host <board-ip> --port 5001 --variant c --seconds 10 --length 1472 --burst-size 32 --socket-buffer 4194304 --output c.jsonl
python vitis/python/host/compare_results.py --python python.jsonl --c c.jsonl
```

Repeat at 64, 512, and 1472 payload bytes, with at least five trials for each
server and payload size. Alternate run order. `throughput_benchmark.py` reports
application payload goodput, not Ethernet wire rate. Save raw records and
server logs and document the board configuration in `../../results/README.md`.
