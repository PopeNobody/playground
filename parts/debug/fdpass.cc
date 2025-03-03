#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <termios.h>
#include <sys/ioctl.h>

/* Receive a file descriptor from another process via a socket */
static int recv_fd(int socket) {
    struct msghdr msg = {0};
    struct cmsghdr *cmsg;
    char buf[CMSG_SPACE(sizeof(int))];
    int *fdptr;
    int received_fd;
    
    /* Initialize message buffer */
    msg.msg_control = buf;
    msg.msg_controllen = sizeof(buf);
    
    /* Receive data to carry control message */
    char dummy;
    struct iovec iov[1];
    iov[0].iov_base = &dummy;
    iov[0].iov_len = sizeof(dummy);
    msg.msg_iov = iov;
    msg.msg_iovlen = 1;
    
    if (recvmsg(socket, &msg, 0) <= 0) {
        perror("recvmsg");
        return -1;
    }
    
    /* Get the received file descriptor */
    cmsg = CMSG_FIRSTHDR(&msg);
    if (!cmsg) {
        fprintf(stderr, "No control message received\n");
        return -1;
    }
    
    if (cmsg->cmsg_level != SOL_SOCKET || cmsg->cmsg_type != SCM_RIGHTS) {
        fprintf(stderr, "Invalid control message\n");
        return -1;
    }
    
    fdptr = (int *) CMSG_DATA(cmsg);
    received_fd = *fdptr;
    
    return received_fd;
}

/* Signal handler for clean shutdown */
static volatile int running = 1;
static int server_sock = -1;
static const char *socket_path = NULL;

void cleanup(void) {
    if (server_sock != -1) {
        close(server_sock);
    }
    if (socket_path) {
        unlink(socket_path);
    }
}

void signal_handler(int sig) {
    running = 0;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <socket_path>\n", argv[0]);
        return 1;
    }
    
    socket_path = argv[1];
    
    /* Set up signal handlers */
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    atexit(cleanup);
    
    /* Remove any existing socket file */
    unlink(socket_path);
    
    /* Create server socket */
    server_sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (server_sock == -1) {
        perror("socket");
        return 1;
    }
    
    /* Set up server address */
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, socket_path, sizeof(addr.sun_path) - 1);
    
    /* Bind socket to address */
    if (bind(server_sock, (struct sockaddr*)&addr, sizeof(addr)) == -1) {
        perror("bind");
        return 1;
    }
    
    /* Listen for connections */
    if (listen(server_sock, 1) == -1) {
        perror("listen");
        return 1;
    }
    
    printf("Waiting for TTY forwarder to connect on %s...\n", socket_path);
    
    /* Accept a connection */
    int client_sock = accept(server_sock, NULL, NULL);
    if (client_sock == -1) {
        perror("accept");
        return 1;
    }
    
    /* Receive the TTY file descriptor */
    int tty_fd = recv_fd(client_sock);
    if (tty_fd == -1) {
        fprintf(stderr, "Failed to receive TTY file descriptor\n");
        close(client_sock);
        return 1;
    }
    
    printf("Received TTY file descriptor: %d\n", tty_fd);
    
    /* Duplicate the TTY to stdin/stdout/stderr for the debugger */
    dup2(tty_fd, STDIN_FILENO);
    dup2(tty_fd, STDOUT_FILENO);
    dup2(tty_fd, STDERR_FILENO);
    
    /* The file descriptor has been duplicated, so we can close the original */
    if (tty_fd > STDERR_FILENO) {
        close(tty_fd);
    }
    
    /* Keep the connection open to hold the TTY */
    printf("TTY is now available for the debugger\n");
    
    /* Tell the parent Perl process we're ready */
    printf("READY\n");
    fflush(stdout);
    
    /* Wait for parent to signal we should exit */
    char buffer[1024];
    while (running && read(client_sock, buffer, sizeof(buffer)) > 0) {
        /* Just keep the connection alive */
    }
    
    printf("Closing TTY session\n");
    close(client_sock);
    
    return 0;
}
