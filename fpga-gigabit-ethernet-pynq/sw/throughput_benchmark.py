#!/usr/bin/env python3
"""Measure UDP packet loss and received application goodput over a time window."""

import argparse
import socket
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True, help="FPGA UDP echo address")
    parser.add_argument("--port", type=int, default=5001)
    parser.add_argument("--seconds", type=float, default=5.0)
    parser.add_argument("--length", type=int, default=1472)
    parser.add_argument("--timeout", type=float, default=0.02)
    args = parser.parse_args()
    if not 1 <= args.length <= 1472:
        parser.error("length must be between 1 and 1472 bytes")
    if args.seconds <= 0:
        parser.error("seconds must be greater than zero")

    sent = 0
    received = 0
    received_bytes = 0
    sequence = 0
    payload = bytearray(index & 0xFF for index in range(args.length))
    start = time.monotonic()
    deadline = start + args.seconds

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setblocking(False)
        sock.connect((args.host, args.port))
        while time.monotonic() < deadline:
            packet = bytearray(payload)
            sequence_bytes = sequence.to_bytes(4, "big")
            sequence_size = min(4, args.length)
            packet[:sequence_size] = sequence_bytes[4 - sequence_size:]
            try:
                sock.send(bytes(packet))
                sent += 1
                sequence = (sequence + 1) & 0xFFFFFFFF
            except (BlockingIOError, InterruptedError):
                pass

            while True:
                try:
                    data = sock.recv(2048)
                except (BlockingIOError, InterruptedError):
                    break
                except OSError:
                    break
                received += 1
                received_bytes += len(data)

        sock.setblocking(True)
        sock.settimeout(args.timeout)
        while True:
            try:
                data = sock.recv(2048)
            except socket.timeout:
                break
            received += 1
            received_bytes += len(data)

    elapsed = time.monotonic() - start
    lost = max(0, sent - received)
    goodput_mbps = (received_bytes * 8.0) / (elapsed * 1_000_000.0)
    loss_percent = 100.0 * lost / sent if sent else 0.0
    print("duration: {:.3f} s".format(elapsed))
    print("sent: {}, received: {}, lost: {} ({:.2f}%)".format(
        sent, received, lost, loss_percent))
    print("application goodput: {:.3f} Mbps".format(goodput_mbps))


if __name__ == "__main__":
    main()
