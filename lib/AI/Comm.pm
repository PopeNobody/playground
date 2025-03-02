package AI::Comm;

use strict;
use warnings;
use Exporter 'import';
use IO::Socket::UNIX;
use JSON;
use Path::Tiny;
use Nobody::Util;
use threads;
use threads::shared;
use Thread::Queue;

our @EXPORT_OK = qw(start_comm_server send_message broadcast_message register_handler);

my $SOCKET_DIR = path("ai_sockets");
$SOCKET_DIR->mkpath unless $SOCKET_DIR->exists;

# Shared queue for messages
my $message_queue = Thread::Queue->new();

# Handlers for different message types
my %handlers;

# Store instance information
my $instance_id;
my $instance_type;
my $socket_path;

# Start the communication server
sub start_comm_server {
    my ($id, $type) = @_;
    
    $instance_id = $id;
    $instance_type = $type;
    $socket_path = "$SOCKET_DIR/$id.sock";
    
    # Remove old socket if it exists
    unlink $socket_path if -e $socket_path;
    
    # Create a message handler thread
    my $thread = threads->create(\&_message_handler_thread);
    $thread->detach();
    
    # Create a Unix domain socket server
    my $server = IO::Socket::UNIX->new(
        Type   => SOCK_STREAM,
        Local  => $socket_path,
        Listen => 5
    ) or die "Can't create server socket: $!";
    
    print "AI Comm Server $instance_id ($instance_type) listening on $socket_path\n";
    
    # Handle incoming connections in a separate thread
    my $server_thread = threads->create(sub {
        while (my $client = $server->accept()) {
            my $input = <$client>;
            chomp $input if defined $input;
            
            eval {
                my $message = decode_json($input);
                
                # Add to message queue for processing
                $message_queue->enqueue($message);
                
                # Send acknowledgment
                print $client encode_json({
                    status => 'ok',
                    message => "Message received by $instance_id"
                }) . "\n";
            } or do {
                print $client encode_json({
                    status => 'error',
                    message => "Invalid message format"
                }) . "\n";
            };
            
            close $client;
        }
    });
    $server_thread->detach();
    
    return {
        id => $instance_id,
        type => $instance_type,
        socket => $socket_path
    };
}

# Message processing thread
sub _message_handler_thread {
    while (1) {
        my $message = $message_queue->dequeue();
        my $type = $message->{type} || 'unknown';
        
        if (exists $handlers{$type}) {
            foreach my $handler (@{$handlers{$type}}) {
                eval {
                    $handler->($message);
                };
                if ($@) {
                    warn "Error in message handler for type '$type': $@";
                }
            }
        } elsif (exists $handlers{'*'}) {
            # Call wildcard handlers
            foreach my $handler (@{$handlers{'*'}}) {
                eval {
                    $handler->($message);
                };
                if ($@) {
                    warn "Error in wildcard message handler: $@";
                }
            }
        }
    }
}

# Register a handler for a message type
sub register_handler {
    my ($type, $handler) = @_;
    push @{$handlers{$type}}, $handler;
}

# Send a message to a specific instance
sub send_message {
    my ($target_id, $message) = @_;
    
    # Add sender information
    $message->{sender} = {
        id => $instance_id,
        type => $instance_type
    };
    
    # Add timestamp
    $message->{timestamp} = time();
    
    my $target_socket = "$SOCKET_DIR/$target_id.sock";
    
    unless (-e $target_socket) {
        warn "Target socket $target_socket does not exist";
        return 0;
    }
    
    my $client = IO::Socket::UNIX->new(
        Peer => $target_socket
    );
    
    unless ($client) {
        warn "Could not connect to $target_socket: $!";
        return 0;
    }
    
    print $client encode_json($message) . "\n";
    my $response = <$client>;
    close $client;
    
    my $result;
    eval {
        $result = decode_json($response);
    };
    
    return $result && $result->{status} eq 'ok';
}

# Broadcast a message to all instances
sub broadcast_message {
    my ($message) = @_;
    
    # Add sender information
    $message->{sender} = {
        id => $instance_id,
        type => $instance_type
    };
    
    # Add timestamp
    $message->{timestamp} = time();
    
    my @results;
    
    # Find all sockets in the directory
    for my $socket_file ($SOCKET_DIR->children) {
        next unless $socket_file =~ /\.sock$/;
        my $target_id = $socket_file->basename;
        $target_id =~ s/\.sock$//;
        
        # Don't send to self
        next if $target_id eq $instance_id;
        
        push @results, {
            id => $target_id,
            success => send_message($target_id, $message)
        };
    }
    
    return \@results;
}

# Clean up on exit
sub END {
    unlink $socket_path if defined $socket_path && -e $socket_path;
}

1;
