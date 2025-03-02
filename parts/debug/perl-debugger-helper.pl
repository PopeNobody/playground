package DebugTTY;

use strict;
use warnings;
use autodie;
use Exporter 'import';
use POSIX qw(mkfifo);
use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile rel2abs);
use IPC::Open3;
use Symbol qw(gensym);

our @EXPORT_OK = qw(start_debug_tty);

my $SCRIPT_DIR = dirname(rel2abs(__FILE__));
my $TTY_FORWARDER = catfile($SCRIPT_DIR, 'tty-forwarder');
my $TTY_RECEIVER = catfile($SCRIPT_DIR, 'tty-receiver');

# Compile the C programs if they don't exist
sub _ensure_binaries {
    my $cc = $ENV{CC} || 'gcc';
    
    unless (-x $TTY_FORWARDER) {
        my $forwarder_src = catfile($SCRIPT_DIR, 'tty-forwarder.c');
        system($cc, '-o', $TTY_FORWARDER, $forwarder_src) == 0
            or die "Failed to compile $forwarder_src: $?";
    }
    
    unless (-x $TTY_RECEIVER) {
        my $receiver_src = catfile($SCRIPT_DIR, 'tty-receiver.c');
        system($cc, '-o', $TTY_RECEIVER, $receiver_src) == 0
            or die "Failed to compile $receiver_src: $?";
    }
}

# Start a new TTY for debugging a forked process
sub start_debug_tty {
    _ensure_binaries();
    
    # Create a temporary directory for our socket
    my $temp_dir = tempdir(CLEANUP => 1);
    my $socket_path = catfile($temp_dir, 'debug_tty.sock');
    
    # Start the receiver first
    my $receiver_pid = fork();
    if ($receiver_pid == 0) {
        # Child process - exec the receiver
        exec($TTY_RECEIVER, $socket_path);
        die "Failed to exec $TTY_RECEIVER: $!";
    }
    
    # Give the receiver a moment to initialize
    sleep(1);
    
    # Start the forwarder in a new tmux window or pane
    my ($tmux_cmd, $exit_code);
    if ($ENV{TMUX}) {
        # We're in tmux, create a new pane
        $tmux_cmd = "tmux split-window -h '$TTY_FORWARDER $socket_path'";
    } else {
        # Not in tmux, create a new xterm
        $tmux_cmd = "xterm -e '$TTY_FORWARDER $socket_path' &";
    }
    
    system($tmux_cmd);
    
    # Wait for the receiver to be ready
    open(my $ready_pipe, '-|', "tail -f /proc/$receiver_pid/fd/1 | grep -m 1 READY");
    my $ready = <$ready_pipe>;
    close($ready_pipe);
    
    return {
        pid => $receiver_pid,
        socket => $socket_path,
        temp_dir => $temp_dir,
        cleanup => sub {
            # Kill the receiver process
            kill('TERM', $receiver_pid);
            waitpid($receiver_pid, 0);
            
            # Socket will be cleaned up by the receiver
        }
    };
}

1;
