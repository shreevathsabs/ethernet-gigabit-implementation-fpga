# Lead FPGA Engineer Meeting: Study Guide

**Project:** PS-vs-PS UDP echo performance on the TUL PYNQ-Z2
**Purpose:** Explain the architecture, code, experiment, and evidence honestly.
**Important:** The PYNQ-Z2 board has not yet been measured for this project. Do
not present any localhost result, predicted speedup, or planned test as a board
result.

## 1. Memorize this 30-second explanation

> “I’m comparing two UDP echo-server implementations on the PYNQ-Z2’s Zynq
> Processing System. The baseline is Python and makes one receive and one send
> socket call per datagram. The candidate is C on Linux and uses `recvmmsg`
> and `sendmmsg` to process up to 32 queued datagrams per call. Both use the
> same PS GEM Ethernet path and the same host-generated traffic. I will compare
> throughput, packet loss, latency, and CPU use over repeated board trials.
> Batching may reduce per-packet system-call overhead, but I have not measured
> an improvement on the board yet.”

If asked whether the design is in the FPGA fabric:

> “No. The selected built-in Ethernet jack is connected to the Zynq PS GEM, so
> the network applications run on the ARM under Linux. The PL is not in this
> Ethernet datapath, and Vivado is not required for this comparison.”

## 2. What the project is—and is not

| It is | It is not |
|---|---|
| A controlled software datapath comparison on real Zynq PS hardware | A custom PL MAC or FPGA network stack |
| A Python baseline versus a Linux C batching candidate | A comparison of two PHYs or two Ethernet controllers |
| An application-level UDP echo benchmark | A claim of full Gigabit line-rate measurement |
| A hypothesis to test on the board | Evidence that C or batching is automatically faster |

The board’s ARM processor is real hardware, just as the PL is real hardware.
The distinction is that the PS executes instructions and Linux software; the PL
implements custom configurable digital circuits.

## 3. Architecture and packet path

```text
Host PC
  Python benchmark
    |  UDP/IP/Ethernet request
    v
Ethernet cable / optional switch
    |
PYNQ-Z2 RJ45 + RTL8211E PHY
    |  board PHY-to-PS interface
Zynq PS GEM Ethernet controller
    |
Linux GEM driver + kernel IP/UDP stack
    |
UDP socket bound to port 5001
    +--> Baseline: Python recvfrom() -> sendto()
    `--> Candidate: C recvmmsg() -> sendmmsg()
    |
UDP echo reply returns over the same path to the host
```

The two server programs must be run **one at a time**, because both bind the
same UDP port. The common board, PHY, GEM, Linux stack, network path, host
benchmark, and packet format are controls. The server implementation is the
intentional independent variable.

## 4. What changed in the code

### Python baseline — `sw/udp_echo_server.py`

The server creates an IPv4 datagram socket, requests send/receive buffers,
binds to `0.0.0.0:5001`, receives one datagram with `recvfrom()`, then returns
that exact datagram to its sender with `sendto()`. The loop is simple and easy
to inspect, which makes it a useful baseline.

### Batched C candidate — `sw/udp_echo_server_batch.c`

The C server prepares arrays of 32 packet slots and Linux message structures.
Each `recvmmsg()` call can receive up to 32 queued datagrams; each `sendmmsg()`
call can return multiple echo datagrams. It compacts valid packet entries,
preserves each sender's address, retries a partially completed send batch,
rejects datagrams larger than the 1472-byte configured UDP payload limit, and
prints packet, byte, wall-clock, and process-CPU counters when stopped.

`BATCH_SIZE=32` is the **maximum batch capacity**, not a promise that all calls
contain 32 packets. `MSG_WAITFORONE` blocks until the first datagram arrives,
then receives messages already queued, up to the batch limit. Linux support
must be checked on the exact PYNQ image; `recvmmsg()` / `sendmmsg()` are Linux
APIs, not portable POSIX APIs.

### Host tools

- `sw/udp_loopback_test.py` sends deterministic payloads sequentially and
  requires exact byte-for-byte echoes.
- `sw/throughput_benchmark.py` encodes a sequence number in the first 8 bytes,
  sends in configured bursts, checks returned length and payload, tracks
  unique, duplicate, corrupt, and unknown replies, and reports throughput,
  loss, and round-trip latency. It writes one JSON object per run.
- `sw/compare_results.py` reads Python and C JSONL files, rejects mismatched
  configurations, and compares their per-metric medians.

## 5. Key terms to explain clearly

| Term | Simple explanation |
|---|---|
| PS | Zynq processing system: ARM cores and fixed peripherals, including GEM |
| PL | FPGA programmable logic fabric; not used for this project's Ethernet path |
| GEM | Zynq PS Ethernet MAC/controller used by the built-in jack |
| PHY | Physical-layer chip between the board's MAC interface and Ethernet cable |
| UDP | Datagram transport: message-oriented, but it does not guarantee delivery, ordering, or retransmission |
| Socket | Linux application's interface to send/receive network datagrams |
| System call | Transition from an application into the Linux kernel to request an operation |
| `recvfrom` / `sendto` | Ordinary per-datagram receive and send calls |
| `recvmmsg` / `sendmmsg` | Linux calls that receive/send arrays of messages in one call |
| Batch | Multiple individual UDP datagrams handled by one syscall; they remain separate datagrams |
| Goodput | Useful echoed payload data per unit time, excluding protocol headers |
| RTT | Host-side elapsed time from sending a datagram until its valid echo returns |
| Socket buffer | Kernel queue capacity for a socket; requested size may be clamped or reported differently |

## 6. Why use 1472-byte maximum payload?

For a basic Ethernet MTU of 1500 bytes with IPv4 and no IP options:

```text
1500-byte IP MTU - 20-byte IPv4 header - 8-byte UDP header = 1472-byte UDP payload
```

The project also tests 64-byte and 512-byte payloads. Smaller packets emphasize
per-packet work; a near-MTU payload tests byte throughput with fewer packets.
Actual behavior can depend on the network path and host MTU.

## 7. Benchmark metrics and formulas

Let `Nsent` be requests sent during the timed period, `Nunique` be valid,
unique echoes observed during the measurement plus drain interval, `L` be
payload bytes, and `T` be the configured measurement seconds.

```text
Reply rate (packets/s) = Nunique / T

Application goodput (Mbps) =
    Nunique * L * 8 / T / 1,000,000

Loss (%) = max(0, Nsent - Nunique) / Nsent * 100

RTT = host monotonic time at valid echo - host monotonic time at send
```

The current benchmark reports goodput using valid unique payload bytes divided
by the configured measurement window. Replies are drained for a further
configured interval and can count toward `Nunique`; document this when
presenting results. Goodput is application payload throughput, **not** the
Ethernet wire rate. It includes host, Linux, driver, and socket/application
effects, and excludes link-layer/IP/UDP overhead.

Mean, median (p50), and p95 latency help reveal whether a throughput gain
comes with a latency cost. Loss is calculated after the drain interval.

## 8. Literature survey and research gap

The sources listed in the slide deck establish the APIs and testing context:

1. Python's socket documentation describes the normal datagram interface used
   for the baseline.
2. Linux `recvmmsg(2)` and `sendmmsg(2)` document message-vector calls and
   their possible performance benefits for some applications. Partial
   `sendmmsg()` completion must be handled.
3. Linux NAPI documentation shows that driver/kernel packet processing and
   coalescing behavior also affect observed performance.
4. PYNQ documentation describes using Python for productivity and lower-level
   code where efficiency is needed.
5. RFC 2544 is a source of disciplined benchmarking ideas; this project is
   **not** an RFC 2544-compliant network-device test.

Do not claim “nobody has studied batching.” The defensible project gap is:

> “The repository has no controlled measurements yet for these two UDP echo
> implementations on the specific PYNQ-Z2 board image and PS GEM path. This
> project measures that configuration under documented, matched conditions.”

**Research question:** On the PYNQ-Z2 PS, does a C UDP server using batched
Linux socket calls improve reply rate or payload goodput versus a Python
per-datagram server, without unacceptable loss, corruption, latency, or CPU
cost?

**Hypothesis, not result:** Batching may reduce application/kernel transition
overhead at high packet rates. If traffic is sparse, the kernel, driver, host,
link, or Python load generator may dominate, and the gain may be small or
unmeasurable.

## 9. Fair experimental procedure

1. Record the PYNQ image/kernel, ARM architecture, Python version, GCC version,
   link speed/duplex, network topology, and actual socket-buffer reports.
2. Compile the C candidate on the board with the documented warnings enabled:
   `gcc -O3 -Wall -Wextra -Werror -std=gnu11 ...`.
3. Run the exact-byte loopback test against each server before throughput
   testing. Resolve any corruption or server compatibility issue first.
4. Use the same host, cable/switch, board, port, image, packet size, burst
   size, test duration, drain interval, and socket-buffer request for both.
5. Test at 64, 512, and 1472 bytes. Run at least five trials per variant and
   payload size. Alternate order (Python then C; C then Python).
6. Run only one server at a time. Warm both in the same way; avoid unrelated
   traffic and heavy background processes.
7. Save every JSONL record, server shutdown summary, commands, and Wireshark
   capture. Record failures and do not silently discard inconvenient runs.
8. Compare medians and show raw run-to-run spread. Include packet loss,
   corruption, RTT, and CPU—not throughput alone.
9. State limitations. If the results are noisy or overlap, report “no clear
   improvement in this setup” rather than forcing a positive conclusion.

## 10. Important experimental caveat to know before the meeting

The C server supports a maximum batch of 32, and the host sends bursts of up to
32. **The current C server does not report a histogram of the actual
`recvmmsg()` return counts.** Therefore, do not claim that it consistently
processed 32 packets per syscall. The lead engineer may reasonably ask whether
the host burst and scheduler let messages accumulate in the board's socket
queue.

Recommended improvement before final results: count `received` from every
`recvmmsg()` call into a histogram (1, 2, ..., 32), and report average batch
occupancy and the fraction of calls with more than one packet. Also capture
kernel/system CPU separately from process CPU. This would substantiate whether
batching actually occurred and distinguish fewer syscalls from other effects.

Additional points:

- The host benchmark records its own requested and actual socket buffers.
  Both servers print actual board-side socket buffer values; save those logs
  and compare them too.
- The comparator verifies common requested settings and reports medians, but
  does not calculate confidence intervals or statistical significance. Show
  each run or min/median/max (or a box plot) in the presentation.
- A large offered load can make the host generator the bottleneck. CPU usage
  and loss at both ends help identify this.
- The C server's process CPU seconds are not the same thing as system-wide CPU
  percentage. Label exactly what was measured.

## 11. Likely lead-engineer questions and strong answers

### “Why is this an FPGA project if your code is not in the PL?”

“It is a Zynq embedded-system project on the PYNQ-Z2, comparing two PS software
datapaths. I chose the PS because the board's built-in Ethernet PHY connects
to the PS GEM, not to PL RGMII pins. I am not claiming an FPGA-fabric network
stack. If the requirement is custom PL packet processing, this project needs
an external PL-connected Ethernet PHY or a separately designed PS-to-PL AXI
packet datapath.”

### “What exactly is new?”

“The implementation candidate replaces one-message-at-a-time Python socket
calls with a C Linux server that batches receive and send operations, then
tests both with one controlled host benchmark on the target board. The novelty
claim is a measured platform-specific comparison, not invention of the Linux
batch APIs.”

### “Why should C be faster?”

“It may do fewer per-message language/runtime and syscall transitions when
multiple datagrams are queued. That is a mechanism and hypothesis. It is not
guaranteed: host generation, Linux scheduling, driver processing, or link
capacity can be the bottleneck.”

### “What do `recvmmsg` and `sendmmsg` change?”

“They accept arrays of message structures so one syscall can receive or send
multiple separate UDP datagrams. They do not merge the datagrams into one UDP
packet. The return value is the number handled, so the send path must handle
partial completion.”

### “How do you know packets were not lost or corrupted?”

“The host places a monotonically increasing sequence in each payload and
checks the echoed sequence, exact datagram length, and remaining payload bytes.
It reports unique replies, lost sequences, duplicates, corrupt data, and
unknown replies. A separate sequential loopback test checks full byte
integrity.”

### “How do you prove the C version is better?”

“I will compare repeated paired board runs at identical payload sizes and
offered load, alternate the order, and report medians and run-to-run spread for
goodput/reply rate, loss, RTT, and CPU. I will only claim improvement if the
performance metric improves consistently without unacceptable correctness or
latency regressions.”

### “Is this 1 Gb/s throughput?”

“No. The benchmark measures application-level echoed UDP payload goodput. It
includes the host, Linux, driver, and application, and excludes Ethernet/IP/UDP
headers. The negotiated link may be Gigabit, but that does not make the
application measurement wire-rate line-rate.”

### “Why test small and large datagrams?”

“Small packets increase packets per second and emphasize per-packet overhead.
Large packets move more payload bytes per packet and emphasize byte throughput.
Testing both helps identify whether the change affects packet rate, byte rate,
or both.”

### “What if your C code does not compile on the board?”

“The candidate uses Linux-specific `recvmmsg`/`sendmmsg` and `_GNU_SOURCE`.
First I will check the board's kernel/libc/compiler and compile it on the
target. If unavailable, I will report the compatibility issue and either use a
supported Linux image or choose a portable alternative before performance
testing.”

### “What is the main limitation today?”

“There are no board measurements yet. Also, the server does not report actual
receive batch sizes, so I cannot yet show how often batching occurs. I need to
add that instrumentation and collect repeated runs before making a performance
claim.”

### “Why not use Vivado or the PL?”

“Vivado does not connect the onboard PHY to PL. The built-in jack is served by
the PS GEM. PL Ethernet would require external RGMII hardware or a designed
AXI/DMA connection to the PS GEM, which is a different project.”

## 12. Be ready to explain these code locations

| File | What to point out |
|---|---|
| `sw/udp_echo_server.py` | Socket setup, buffer request, bind, receive-one/send-one loop, shutdown counters |
| `sw/udp_echo_server_batch.c` | 32 message slots, `recvmmsg`, oversize/truncation handling, peer-address preservation, partial `sendmmsg` loop |
| `sw/throughput_benchmark.py` | 8-byte sequence number, burst sender, receive/drain loop, integrity check, formulas, JSON output |
| `sw/udp_loopback_test.py` | Sequential deterministic test payload and exact echoed-byte comparison |
| `sw/compare_results.py` | Configuration matching, medians, throughput percent change, loss percentage-point change |
| `results/README.md` | Empty template; board evidence has not been filled in |

## 13. Short preparation plan for tonight

1. Read the 30-second explanation and architecture until you can draw the
   packet path from memory.
2. Open the Python and C files. Be able to explain the receive/send loop and
   why a partial `sendmmsg()` result is handled.
3. Memorize the payload formula, metric formulas, and the statement that
   batching is only a hypothesis until measured.
4. Read the “experimental caveat” section. Volunteer that actual batch
   occupancy is not instrumented yet; it demonstrates engineering judgement.
5. Rehearse the first four likely questions above, especially why this is PS
   rather than PL and how improvement will be proven.
6. Open the presentation and use the architecture, code-delta, methodology,
   and pending-results slides to guide your explanation. Do not invent results.

## 14. References

- Python `socket` documentation:
  <https://docs.python.org/3/library/socket.html>
- Linux `recvmmsg(2)`:
  <https://man7.org/linux/man-pages/man2/recvmmsg.2.html>
- Linux `sendmmsg(2)`:
  <https://man7.org/linux/man-pages/man2/sendmmsg.2.html>
- Linux NAPI networking documentation:
  <https://docs.kernel.org/networking/napi.html>
- PYNQ documentation:
  <https://pynq.readthedocs.io/en/latest/>
- RFC 2544 benchmarking methodology (methodology reference only; this project
  is not RFC 2544 compliant):
  <https://www.rfc-editor.org/rfc/rfc2544>
- AMD Zynq-7000 Technical Reference Manual, UG585:
  <https://docs.amd.com/v/u/en-US/ug585-Zynq-7000-TRM>
