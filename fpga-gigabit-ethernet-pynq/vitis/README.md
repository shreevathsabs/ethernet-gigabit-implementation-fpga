# Software Sections: Vitis, PYNQ Linux, and Host Tools

The built-in PYNQ-Z2 Ethernet jack is handled by the Zynq PS GEM and Linux.
These programs are software applications; they do not load a PL Ethernet
bitstream.

## C Linux application

[`c/udp_echo_server_batch.c`](c/udp_echo_server_batch.c) uses Linux-specific
`recvmmsg()` and `sendmmsg()` socket APIs. It is not a standalone/bare-metal
Vitis application. The simplest supported project workflow is to compile it with GCC on the
running PYNQ Linux image. From the repository root, copy the source to the
board and run the build command there:

```sh
scp vitis/c/udp_echo_server_batch.c xilinx@<board-ip>:/home/xilinx/
ssh xilinx@<board-ip> "cd /home/xilinx && gcc -O3 -Wall -Wextra -Werror -std=gnu11 udp_echo_server_batch.c -o udp_echo_server_batch"
ssh xilinx@<board-ip> "/home/xilinx/udp_echo_server_batch 5001 4194304"
```

Vitis may also be used to build a Linux-targeted application when configured
with a matching Zynq platform, Linux domain, target sysroot, and toolchain for
the PYNQ image. Do not select a standalone domain: the implementation depends
on Linux socket APIs. See [`c/README.md`](c/README.md).

## Python software

Python runs under the PYNQ Linux OS or on the host PC; it is not compiled or
executed by the Vitis IDE. Start
[`python/board/udp_echo_server.py`](python/board/udp_echo_server.py) on the
board after copying it with:

```sh
scp vitis/python/board/udp_echo_server.py xilinx@<board-ip>:/home/xilinx/
ssh xilinx@<board-ip> "python3 /home/xilinx/udp_echo_server.py --port 5001 --socket-buffer 4194304"
```

Run the client tools in [`python/host/`](python/host/) on the host machine.
See [`python/README.md`](python/README.md).

No board measurements are included. Use matched configurations and repeated
trials, then record actual board results in [`../results/README.md`](../results/README.md).
