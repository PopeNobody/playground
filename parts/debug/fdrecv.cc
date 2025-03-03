#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <termios.h>
#include <sys/ioctl.h>

/* Pass a file descriptor to another process over a socket */
static int send_fd(int socket, int fd_to_send) {
    struct msghdr msg = {0};
    struct cmsghdr *cmsg;
    char buf[CMSG_SPACE(sizeof(int))];
    int *fdptr;
    
    /* Initialize message buffer */
    msg.msg_control = buf;
    msg.msg_controllen = sizeof(buf);
    
    /* Initialize control message */
    cmsg = CMSG_FIRSTHDR(&msg);
    cmsg->cmsg_level = SOL_SOCKET;
    cmsg->cmsg_type = SCM_RIGHTS;
    cmsg->cmsg_len = CMSG_LEN(sizeof(int));
    
    /* Store the file descriptor */
    fdptr = (int *) CMSG_DATA(cmsg);
    *fdptr = fd_to_send;
    
    /* Update message length */
    msg.msg_controllen = cmsg->cmsg_len;
    
    /* Send one byte of data to carry the control message */
    char dummy = 'X';
    struct iovec iov[1];
    iov[0].iov_base = &dummy;
    iov[0].iov_len = sizeof(dummy);
    msg.msg_iov = iov;
    msg.msg_iovlen = 1;
    
    return sendmsg(socket, &msg, 0);
}

/* Block all possible signals */
static void block_all_signals(void) {
    sigset_t mask;
    sigfillset(&mask);
    sigprocmask(SIG_BLOCK, &mask, NULL);
    
    /* Set up signal handlers to do nothing */
    struct sigaction act;
    memset(&act, 0, sizeof(act));
    act.sa_handler = SIG_IGN;
    
    for (int i = 1; i < NSIG; i++) {
        sigaction(i, &act, NULL);
    }
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <socket_path>\n", argv[0]);
        return 1;
    }
    
    const char *socket_path = argv[1];
    
    /* Create client socket */
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock == -1) {
        perror("socket");
        return 1;
    }
    
    /* Set up server address */
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, socket_path, sizeof(addr.sun_path) - 1);
    
    /* Connect to server */
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) == -1) {
        perror("connect");
        close(sock);
        return 1;
    }
    
    printf("Connected to %s, forwarding TTY...\n", socket_path);
    
    /* Send our stdin/stdout file descriptor (typically connected to a TTY) */
    int tty_fd = STDOUT_FILENO;
    
    /* Verify it's actually a TTY */
    if (!isatty(tty_fd)) {
        fprintf(stderr, "Error: Not running in a TTY\n");
        close(sock);
        return 1;
    }
    
    /* Get terminal information for later restoration */
    struct termios old_term;
    tcgetattr(tty_fd, &old_term);
    
    /* Put terminal in raw mode */
    struct termios raw;
    memcpy(&raw, &old_term, sizeof(struct termios));
    cfmakeraw(&raw);
    tcsetattr(tty_fd, TCSANOW, &raw);
    
    /* Send the TTY file descriptor to the server */
    if (send_fd(sock, tty_fd) == -1) {
        perror("send_fd");
        tcsetattr(tty_fd, TCSANOW, &old_term);
        close(sock);
        return 1;
    }
    
    printf("TTY forwarded successfully.\n");
    printf("This window will remain active until the debugging session ends.\n");
    
    /* Block all signals to avoid being killed */
    block_all_signals();
    
    /* Wait until the server closes the connection */
    char buffer[1];
    while (read(sock, buffer, 1) > 0) {
        /* Do nothing, just wait */
    }
    
    /* Restore terminal settings */
    tcsetattr(tty_fd, TCSANOW, &old_term);
    close(sock);
    
    printf("Debugging session ended, exiting.\n");
    return 0;
}
