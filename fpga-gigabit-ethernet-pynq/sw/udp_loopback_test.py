#!/usr/bin/env python3
"""Send UDP payloads to a remote echo service and verify exact byte integrity."""

import argparse
import socket
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True, help="FPGA UDP server/echo address")
    parser.add_argument("--port", type=int, default=5001)
    parser.add_argument("--count", type=int, default=100)
    parser.add_argument("--length", type=int, default=256)
    parser.add_argument("--timeout", type=float, default=1.0)
    args = parser.parse_args()
    if args.count <= 0:
        parser.error("count must be greater than zero")
    if not 1 <= args.length <= 1472:
        parser.error("length must be between 1 and 1472 bytes")

    received = 0
    started = time.monotonic()
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(args.timeout)
        sock.connect((args.host, args.port))
        for sequence in range(args.count):
            payload = bytes(((index + sequence) & 0xFF)
                            for index in range(args.length))
            sock.send(payload)
            try:
                echo = sock.recv(2048)
            except socket.timeout:
                print("timeout: packet {} was not echoed".format(sequence))
                continue
            if echo != payload:
                print("integrity failure: packet {}".format(sequence))
                continue
            received += 1

    elapsed = time.monotonic() - started
    print("verified {}/{} packets ({:.1f}%), elapsed {:.3f} s".format(
        received, args.count, 100.0 * received / args.count if args.count else 0.0,
        elapsed))
    if received != args.count:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
