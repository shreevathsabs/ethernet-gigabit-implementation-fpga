# C Linux UDP Echo Server

`udp_echo_server_batch.c` is the C candidate in the PS-vs-PS experiment. It
uses Linux `recvmmsg()` and `sendmmsg()` to process up to 32 separate UDP
datagrams per syscall. The capacity is a maximum, not an assertion that the
kernel returns full batches. Both calls are Linux APIs, so this source requires
a Linux target and GNU C library/toolchain.

## Build on the board

Copy the source to a booted PYNQ-Z2, then compile and run it:

```sh
gcc -O3 -Wall -Wextra -Werror -std=gnu11 udp_echo_server_batch.c \
  -o udp_echo_server_batch
./udp_echo_server_batch 5001 4194304
```

The arguments are UDP port and requested socket-buffer size in bytes. Stop the
server with Ctrl-C to print its summary. Do not run the Python server at the
same time; both use the same port.

Vitis IDE is optional. To use it, configure an application for a Linux domain
with a platform, sysroot, and compiler matching the board's PYNQ image. A
standalone/bare-metal domain is incompatible with this source's Linux socket
calls.
