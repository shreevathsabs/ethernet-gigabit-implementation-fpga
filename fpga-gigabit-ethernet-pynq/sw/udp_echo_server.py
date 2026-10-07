#!/usr/bin/env python3
"""Run a UDP echo endpoint on the PYNQ-Z2 ARM/Linux processing system."""

import argparse
import socket
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bind", default="0.0.0.0",
                        help="local interface to bind (default: all interfaces)")
    parser.add_argument("--port", type=int, default=5001)
    parser.add_argument("--max-payload", type=int, default=1472)
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("port must be between 1 and 65535")
    if not 1 <= args.max_payload <= 65507:
        parser.error("max-payload must be between 1 and 65507")

    packets = 0
    byte_count = 0
    started = time.monotonic()
    address = (args.bind, args.port)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as server:
        server.bind(address)
        server.settimeout(1.0)
        print("UDP echo listening on {}:{}".format(*address), flush=True)
        try:
            while True:
                try:
                    payload, peer = server.recvfrom(args.max_payload + 1)
                except socket.timeout:
                    continue
                if len(payload) > args.max_payload:
                    continue
                server.sendto(payload, peer)
                packets += 1
                byte_count += len(payload)
        except KeyboardInterrupt:
            elapsed = time.monotonic() - started
            print("\nreceived {} packets, echoed {} bytes in {:.3f} s".format(
                packets, byte_count, elapsed))


if __name__ == "__main__":
    main()
