#!/usr/bin/env python3
"""Compare repeated JSONL UDP benchmark runs for Python and batched-C PS servers."""

import argparse
import json
import statistics


METRICS = (
    ("reply_packets_per_second", "Replies/s", True, False),
    ("goodput_mbps", "Goodput Mbps", True, False),
    ("loss_percent", "Loss %", False, True),
    ("latency_mean_ms", "Mean RTT ms", False, False),
    ("latency_p95_ms", "P95 RTT ms", False, False),
)


def load_runs(path, expected_variant):
    runs = []
    with open(path, encoding="utf-8") as source:
        for line_number, line in enumerate(source, 1):
            if not line.strip():
                continue
            try:
                result = json.loads(line)
            except json.JSONDecodeError as error:
                raise ValueError("{}:{}: {}".format(path, line_number, error))
            if result.get("variant") != expected_variant:
                raise ValueError("{} contains variant {!r}, expected {!r}".format(
                    path, result.get("variant"), expected_variant))
            runs.append(result)
    if not runs:
        raise ValueError("{} contains no benchmark results".format(path))
    return runs


def median_metric(runs, name):
    values = [run[name] for run in runs if run.get(name) is not None]
    return statistics.median(values) if values else None


def format_value(value):
    return "n/a" if value is None else "{:.3f}".format(value)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--python", required=True,
                        help="JSONL file containing Python baseline runs")
    parser.add_argument("--c", required=True,
                        help="JSONL file containing batched C runs")
    args = parser.parse_args()

    try:
        python_runs = load_runs(args.python, "python")
        c_runs = load_runs(args.c, "c")
    except (OSError, ValueError) as error:
        parser.error(str(error))

    common_settings = ("host", "port", "payload_bytes", "burst_size", "test_seconds",
                       "drain_seconds", "socket_buffer_requested_bytes")
    for key in common_settings:
        if any(run.get(key) != python_runs[0].get(key)
               for run in python_runs + c_runs):
            parser.error("runs do not share the same {}".format(key))

    print("Median of {} Python runs and {} C runs".format(
        len(python_runs), len(c_runs)))
    print("{:<18} {:>14} {:>14} {:>14}".format(
        "Metric", "Python", "Batched C", "Change"))
    print("-" * 64)
    for metric, label, higher_is_better, absolute_difference in METRICS:
        baseline = median_metric(python_runs, metric)
        improved = median_metric(c_runs, metric)
        if baseline is None or improved is None:
            change = "n/a"
        elif absolute_difference:
            change = "{:+.3f} pp".format(baseline - improved)
        elif baseline == 0:
            change = "n/a"
        else:
            percent = (improved - baseline) * 100.0 / abs(baseline)
            if not higher_is_better:
                percent = -percent
            change = "{:+.2f}%".format(percent)
        print("{:<18} {:>14} {:>14} {:>14}".format(
            label, format_value(baseline), format_value(improved), change))


if __name__ == "__main__":
    main()
