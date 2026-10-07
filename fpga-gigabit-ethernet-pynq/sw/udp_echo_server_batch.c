#define _GNU_SOURCE

#include <arpa/inet.h>
#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

#define MAX_PAYLOAD 1472
#define BATCH_SIZE 32
#define DEFAULT_PORT 5001
#define DEFAULT_SOCKET_BUFFER (4 * 1024 * 1024)

struct packet_slot {
    unsigned char data[MAX_PAYLOAD];
    struct sockaddr_in peer;
};

static volatile sig_atomic_t stop_requested = 0;

static void handle_signal(int signal_number)
{
    (void)signal_number;
    stop_requested = 1;
}

static int parse_positive(const char *text, long maximum, long *value)
{
    char *end = NULL;
    long parsed;

    errno = 0;
    parsed = strtol(text, &end, 10);
    if (errno != 0 || end == text || *end != '\0' || parsed <= 0 ||
        parsed > maximum) {
        return -1;
    }
    *value = parsed;
    return 0;
}

static double seconds_between(const struct timespec *start,
                              const struct timespec *end)
{
    return (double)(end->tv_sec - start->tv_sec) +
           (double)(end->tv_nsec - start->tv_nsec) / 1000000000.0;
}

int main(int argc, char **argv)
{
    struct packet_slot slots[BATCH_SIZE];
    struct iovec receive_iov[BATCH_SIZE];
    struct iovec send_iov[BATCH_SIZE];
    struct mmsghdr receive_messages[BATCH_SIZE];
    struct mmsghdr send_messages[BATCH_SIZE];
    struct sockaddr_in local_address;
    struct sigaction action;
    struct timespec wall_start;
    struct timespec wall_end;
    struct timespec cpu_start;
    struct timespec cpu_end;
    long port = DEFAULT_PORT;
    long socket_buffer = DEFAULT_SOCKET_BUFFER;
    int socket_buffer_setting;
    unsigned long long packets_received = 0;
    unsigned long long packets_echoed = 0;
    unsigned long long bytes_echoed = 0;
    unsigned long long oversized_packets = 0;
    int receive_buffer_actual;
    int send_buffer_actual;
    socklen_t option_size;
    int socket_fd;
    unsigned int index;

    if (argc > 3 ||
        (argc >= 2 && parse_positive(argv[1], 65535, &port) != 0) ||
        (argc == 3 && parse_positive(argv[2], 64 * 1024 * 1024,
                                     &socket_buffer) != 0)) {
        fprintf(stderr, "Usage: %s [port 1..65535] [socket-buffer-bytes]\n",
                argv[0]);
        return EXIT_FAILURE;
    }

    memset(slots, 0, sizeof(slots));
    memset(receive_messages, 0, sizeof(receive_messages));
    memset(send_messages, 0, sizeof(send_messages));
    for (index = 0; index < BATCH_SIZE; ++index) {
        receive_iov[index].iov_base = slots[index].data;
        receive_iov[index].iov_len = sizeof(slots[index].data);
        receive_messages[index].msg_hdr.msg_name = &slots[index].peer;
        receive_messages[index].msg_hdr.msg_namelen =
            sizeof(slots[index].peer);
        receive_messages[index].msg_hdr.msg_iov = &receive_iov[index];
        receive_messages[index].msg_hdr.msg_iovlen = 1;

        send_iov[index].iov_base = slots[index].data;
        send_iov[index].iov_len = 0;
        send_messages[index].msg_hdr.msg_name = &slots[index].peer;
        send_messages[index].msg_hdr.msg_namelen =
            sizeof(slots[index].peer);
        send_messages[index].msg_hdr.msg_iov = &send_iov[index];
        send_messages[index].msg_hdr.msg_iovlen = 1;
    }

    socket_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (socket_fd < 0) {
        perror("socket");
        return EXIT_FAILURE;
    }
    socket_buffer_setting = (int)socket_buffer;
    if (setsockopt(socket_fd, SOL_SOCKET, SO_RCVBUF, &socket_buffer_setting,
                   sizeof(socket_buffer_setting)) < 0 ||
        setsockopt(socket_fd, SOL_SOCKET, SO_SNDBUF, &socket_buffer_setting,
                   sizeof(socket_buffer_setting)) < 0) {
        perror("setsockopt");
        close(socket_fd);
        return EXIT_FAILURE;
    }
    option_size = sizeof(receive_buffer_actual);
    if (getsockopt(socket_fd, SOL_SOCKET, SO_RCVBUF, &receive_buffer_actual,
                   &option_size) < 0) {
        perror("getsockopt SO_RCVBUF");
        close(socket_fd);
        return EXIT_FAILURE;
    }
    option_size = sizeof(send_buffer_actual);
    if (getsockopt(socket_fd, SOL_SOCKET, SO_SNDBUF, &send_buffer_actual,
                   &option_size) < 0) {
        perror("getsockopt SO_SNDBUF");
        close(socket_fd);
        return EXIT_FAILURE;
    }

    memset(&local_address, 0, sizeof(local_address));
    local_address.sin_family = AF_INET;
    local_address.sin_addr.s_addr = htonl(INADDR_ANY);
    local_address.sin_port = htons((uint16_t)port);
    if (bind(socket_fd, (struct sockaddr *)&local_address,
             sizeof(local_address)) < 0) {
        perror("bind");
        close(socket_fd);
        return EXIT_FAILURE;
    }

    memset(&action, 0, sizeof(action));
    action.sa_handler = handle_signal;
    sigemptyset(&action.sa_mask);
    if (sigaction(SIGINT, &action, NULL) < 0 ||
        sigaction(SIGTERM, &action, NULL) < 0) {
        perror("sigaction");
        close(socket_fd);
        return EXIT_FAILURE;
    }
    if (clock_gettime(CLOCK_MONOTONIC, &wall_start) < 0 ||
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &cpu_start) < 0) {
        perror("clock_gettime");
        close(socket_fd);
        return EXIT_FAILURE;
    }

    printf("C batched server listening on 0.0.0.0:%ld "
           "(batch=%d requested_socket_buffer=%ld "
           "actual_receive_buffer=%d actual_send_buffer=%d)\n",
           port, BATCH_SIZE, socket_buffer, receive_buffer_actual,
           send_buffer_actual);
    fflush(stdout);

    while (!stop_requested) {
        int received;
        unsigned int slot_index;

        for (index = 0; index < BATCH_SIZE; ++index) {
            receive_messages[index].msg_hdr.msg_namelen =
                sizeof(slots[index].peer);
            receive_messages[index].msg_hdr.msg_flags = 0;
            receive_messages[index].msg_len = 0;
        }

        received = recvmmsg(socket_fd, receive_messages, BATCH_SIZE,
                            MSG_WAITFORONE | MSG_TRUNC, NULL);
        if (received < 0) {
            if (errno == EINTR && stop_requested) {
                break;
            }
            if (errno == EINTR) {
                continue;
            }
            perror("recvmmsg");
            close(socket_fd);
            return EXIT_FAILURE;
        }
        packets_received += (unsigned int)received;

        {
            unsigned int valid_count = 0;
            unsigned int sent_count = 0;

            for (slot_index = 0; slot_index < (unsigned int)received;
                 ++slot_index) {
                if (receive_messages[slot_index].msg_len > MAX_PAYLOAD ||
                    (receive_messages[slot_index].msg_hdr.msg_flags & MSG_TRUNC) != 0) {
                    continue;
                }
                if (valid_count != slot_index) {
                    memmove(slots[valid_count].data, slots[slot_index].data,
                            receive_messages[slot_index].msg_len);
                    slots[valid_count].peer = slots[slot_index].peer;
                }
                send_iov[valid_count].iov_base = slots[valid_count].data;
                send_iov[valid_count].iov_len =
                    receive_messages[slot_index].msg_len;
                send_messages[valid_count].msg_hdr.msg_name =
                    &slots[valid_count].peer;
                send_messages[valid_count].msg_hdr.msg_namelen =
                    receive_messages[slot_index].msg_hdr.msg_namelen;
                send_messages[valid_count].msg_hdr.msg_iov =
                    &send_iov[valid_count];
                send_messages[valid_count].msg_hdr.msg_iovlen = 1;
                send_messages[valid_count].msg_hdr.msg_flags = 0;
                send_messages[valid_count].msg_hdr.msg_control = NULL;
                send_messages[valid_count].msg_hdr.msg_controllen = 0;
                send_messages[valid_count].msg_len = 0;
                valid_count++;
            }

            while (sent_count < valid_count) {
                int sent = sendmmsg(socket_fd, &send_messages[sent_count],
                                    valid_count - sent_count, 0);
                unsigned int sent_index;
                if (sent < 0) {
                    if (errno == EINTR && stop_requested) {
                        break;
                    }
                    if (errno == EINTR) {
                        continue;
                    }
                    perror("sendmmsg");
                    close(socket_fd);
                    return EXIT_FAILURE;
                }
                if (sent == 0) {
                    fprintf(stderr, "sendmmsg returned zero for nonempty batch\n");
                    close(socket_fd);
                    return EXIT_FAILURE;
                }
                for (sent_index = sent_count;
                     sent_index < sent_count + (unsigned int)sent;
                     ++sent_index) {
                    bytes_echoed += send_messages[sent_index].msg_len;
                }
                sent_count += (unsigned int)sent;
            }
            packets_echoed += sent_count;
        }
    }

    if (clock_gettime(CLOCK_MONOTONIC, &wall_end) < 0 ||
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &cpu_end) < 0) {
        perror("clock_gettime");
        close(socket_fd);
        return EXIT_FAILURE;
    }
    printf("\nvariant=c packets_received=%llu packets_echoed=%llu "
           "bytes_echoed=%llu oversized=%llu wall_seconds=%.3f "
           "process_cpu_seconds=%.3f\n",
           packets_received, packets_echoed, bytes_echoed, oversized_packets,
           seconds_between(&wall_start, &wall_end),
           seconds_between(&cpu_start, &cpu_end));
    close(socket_fd);
    return EXIT_SUCCESS;
}
