#!/usr/bin/env python3
"""Run a repeatable UDP echo load test and optionally append JSON Lines results."""

import argparse
import json
import math
import select
import socket
import statistics
import time


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, math.ceil(fraction * len(ordered)) - 1)
    return ordered[max(index, 0)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True, help="PYNQ-Z2 IP address")
    parser.add_argument("--port", type=int, default=5001)
    parser.add_argument("--seconds", type=float, default=5.0)
    parser.add_argument("--length", type=int, default=1472)
    parser.add_argument("--burst-size", type=int, default=32)
    parser.add_argument("--drain-seconds", type=float, default=1.0)
    parser.add_argument("--socket-buffer", type=int, default=4 * 1024 * 1024)
    parser.add_argument("--variant", required=True, choices=("python", "c"))
    parser.add_argument("--output", help="append one JSON result to this JSONL file")
    args = parser.parse_args()
    if not 8 <= args.length <= 1472:
        parser.error("length must be between 8 and 1472 bytes for sequence tracking")
    if not 1 <= args.burst_size <= 32:
        parser.error("burst-size must be between 1 and 32")
    if args.seconds <= 0 or args.drain_seconds < 0:
        parser.error("seconds must be positive and drain-seconds cannot be negative")
    if args.socket_buffer <= 0:
        parser.error("socket-buffer must be positive")
    if not 1 <= args.port <= 65535:
        parser.error("port must be between 1 and 65535")

    sequence_times = {}
    seen_sequences = set()
    latencies_ms = []
    sent = 0
    unique_replies = 0
    duplicates = 0
    corrupt = 0
    unknown = 0
    reply_bytes_received = 0
    send_buffer_actual = 0
    receive_buffer_actual = 0
    payload_tail = bytes(index & 0xFF for index in range(args.length - 8))
    started = time.monotonic()
    deadline = started + args.seconds

    def record_reply(data):
        nonlocal unique_replies, duplicates, corrupt, unknown, reply_bytes_received
        reply_bytes_received += len(data)
        if len(data) != args.length:
            corrupt += 1
            return
        sequence = int.from_bytes(data[:8], "big")
        sent_at = sequence_times.get(sequence)
        if sent_at is None:
            unknown += 1
            return
        if data[8:] != payload_tail:
            corrupt += 1
            return
        if sequence in seen_sequences:
            duplicates += 1
            return
        seen_sequences.add(sequence)
        unique_replies += 1
        latencies_ms.append((time.monotonic() - sent_at) * 1000.0)

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, args.socket_buffer)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, args.socket_buffer)
        send_buffer_actual = sock.getsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF)
        receive_buffer_actual = sock.getsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF)
        sock.connect((args.host, args.port))
        sock.setblocking(False)

        while time.monotonic() < deadline:
            for _ in range(args.burst_size):
                if time.monotonic() >= deadline:
                    break
                sequence = sent
                packet = sequence.to_bytes(8, "big") + payload_tail
                try:
                    sock.send(packet)
                    sequence_times[sequence] = time.monotonic()
                    sent += 1
                except (BlockingIOError, InterruptedError):
                    break
            while True:
                readable, _, _ = select.select([sock], [], [], 0)
                if not readable:
                    break
                try:
                    data = sock.recv(2048)
                except (BlockingIOError, InterruptedError):
                    break
                record_reply(data)

        drain_deadline = time.monotonic() + args.drain_seconds
        while time.monotonic() < drain_deadline:
            remaining = drain_deadline - time.monotonic()
            readable, _, _ = select.select([sock], [], [], remaining)
            if not readable:
                break
            try:
                data = sock.recv(2048)
            except (BlockingIOError, InterruptedError):
                continue
            record_reply(data)

        elapsed = time.monotonic() - started

    lost = max(0, sent - unique_replies)
    result = {
        "variant": args.variant,
        "host": args.host,
        "port": args.port,
        "payload_bytes": args.length,
        "burst_size": args.burst_size,
        "test_seconds": args.seconds,
        "drain_seconds": args.drain_seconds,
        "socket_buffer_requested_bytes": args.socket_buffer,
        "socket_send_buffer_actual_bytes": send_buffer_actual,
        "socket_receive_buffer_actual_bytes": receive_buffer_actual,
        "wall_elapsed_seconds_including_drain": elapsed,
        "measurement_seconds": args.seconds,
        "sent_packets": sent,
        "unique_replies": unique_replies,
        "lost_packets": lost,
        "loss_percent": (100.0 * lost / sent) if sent else 0.0,
        "duplicate_replies": duplicates,
        "corrupt_replies": corrupt,
        "unknown_replies": unknown,
        "echo_bytes_received": reply_bytes_received,
        "goodput_mbps": unique_replies * args.length * 8.0 /
                        args.seconds / 1_000_000.0,
        "reply_packets_per_second": unique_replies / args.seconds,
        "latency_mean_ms": statistics.mean(latencies_ms) if latencies_ms else None,
        "latency_p50_ms": percentile(latencies_ms, 0.50),
        "latency_p95_ms": percentile(latencies_ms, 0.95),
    }

    print(json.dumps(result, indent=2, sort_keys=True))
    if args.output:
        with open(args.output, "a", encoding="utf-8") as output:
            output.write(json.dumps(result, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
