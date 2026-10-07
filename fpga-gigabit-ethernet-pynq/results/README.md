# PS UDP comparison results

No PYNQ-Z2 measurements have been recorded yet. Keep raw JSONL benchmark
outputs and server logs with this report; do not present localhost numbers as
board results.

## Test configuration

| Item | Value |
|---|---|
| Test date/time | |
| PYNQ image and kernel | |
| Board/host link speed and duplex | |
| Host OS and Python version | |
| C compiler/version and flags | |
| Requested / actual socket buffers | |
| Payload sizes, burst size, and duration | |
| Repetitions and run order | |

## Results

Run at least five paired trials for each payload length. Alternate run order
(Python/C then C/Python) and compare medians. Include raw JSONL files, benchmark
output, server CPU summaries, and Wireshark capture references.

| Payload bytes | Variant | Median replies/s | Median goodput Mbps | Median loss % | Median p95 RTT ms | Server CPU seconds | Notes |
|---:|---|---:|---:|---:|---:|---:|---|
| | Python baseline | | | | | | |
| | Batched C | | | | | | |

## Interpretation

State which metric is the primary success criterion before testing. Claim an
improvement only if repeated comparable trials show a consistent benefit
without unacceptable packet loss, corruption, or latency regressions. Include
limitations and any inconclusive measurements.
