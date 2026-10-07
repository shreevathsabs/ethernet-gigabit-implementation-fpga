#!/usr/bin/env python3
"""Baseline PS UDP echo server: one receive and one send call per datagram."""

import argparse
import socket
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bind", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=5001)
    parser.add_argument("--max-payload", type=int, default=1472)
    parser.add_argument("--socket-buffer", type=int, default=4 * 1024 * 1024)
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("port must be between 1 and 65535")
    if not 1 <= args.max_payload <= 65507:
        parser.error("max-payload must be between 1 and 65507")
    if args.socket_buffer <= 0:
        parser.error("socket-buffer must be positive")

    packets = 0
    bytes_echoed = 0
    started = time.monotonic()
    cpu_started = time.process_time()
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as server:
        server.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, args.socket_buffer)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, args.socket_buffer)
        server.bind((args.bind, args.port))
        server.settimeout(1.0)
        print("Python baseline listening on {}:{} "
              "(requested_socket_buffer={} actual_receive_buffer={} "
              "actual_send_buffer={})".format(
                  args.bind, args.port, args.socket_buffer,
                  server.getsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF),
                  server.getsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF)),
              flush=True)
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
                bytes_echoed += len(payload)
        except KeyboardInterrupt:
            elapsed = time.monotonic() - started
            cpu_seconds = time.process_time() - cpu_started
            print("\nvariant=python packets={} bytes={} wall_seconds={:.3f} "
                  "process_cpu_seconds={:.3f}".format(
                      packets, bytes_echoed, elapsed, cpu_seconds))


if __name__ == "__main__":
    main()
