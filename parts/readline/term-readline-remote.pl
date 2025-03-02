package Term::ReadLine::Remote;

use strict;
use warnings;
use base 'Term::ReadLine::Stub';
use IO::Socket::UNIX;
use JSON::PP;
use File::Temp qw(tempdir);
use File::Spec::Functions qw(catfile);
use Carp qw(croak);
use POSIX qw(:sys_wait_h);

our $VERSION = '0.01';
our @ISA = qw(Term::ReadLine::Stub);

# Globals for completion
our $attribs = {};
our @completion_matches = ();
our $completion_func;
our $completion_word;

# Track server process
my $server_pid;
my $socket_path;
my $temp_dir;
my $client_socket;

sub new {
    my ($class, $name, $in, $out) = @_;
    
    my $self = $class->SUPER::new($name, $in, $out);
    $self->{name} = $name;
    $self->{IN} = $in;
    $self->{OUT} = $out;
    
    # Initialize the remote readline server
    $self->_start_server();
    
    return $self;
}

sub _start_server {
    my $self = shift;
    
    # Create temp directory for socket
    $temp_dir = tempdir(CLEANUP => 1);
    $socket_path = catfile($temp_dir, "readline_$$.sock");
    
    # Start the server process
    $server_pid = fork();
    if (!defined $server_pid) {
        croak "Cannot fork: $!";
    }
    
    if ($server_pid == 0) {
        # Child process - exec the C readline server
        my $server_bin = $ENV{READLINE_SERVER_BIN} || 
                        "$FindBin::Bin/readline-server";
        
        unless (-x $server_bin) {
            warn "Cannot find readline-server binary at $server_bin";
            exit(1);
        }
        
        exec($server_bin, $socket_path);
        die "Failed to exec readline-server: $!";
    }
    
    # Wait for the server to initialize
    sleep(1);
    
    # Connect to the server
    $client_socket = IO::Socket::UNIX->new(
        Type => SOCK_STREAM,
        Peer => $socket_path
    ) or croak "Cannot connect to readline server: $!";
    
    # Set up readline attributes
    $self->_send_command({
        cmd => 'init',
        name => $self->{name}
    });
    
    # Install cleanup handlers
    $SIG{__DIE__} = sub { $self->DESTROY; die @_ };
    $SIG{INT} = sub { $self->DESTROY; exit };
    
    return 1;
}

sub _send_command {
    my ($self, $cmd_hash) = @_;
    
    return unless $client_socket;
    
    my $json = encode_json($cmd_hash);
    print $client_socket "$json\n";
    
    my $response = <$client_socket>;
    chomp $response if defined $response;
    
    return defined $response ? decode_json($response) : undef;
}

sub readline {
    my ($self, $prompt) = @_;
    $prompt = '' unless defined $prompt;
    
    my $response = $self->_send_command({
        cmd => 'readline',
        prompt => $prompt
    });
    
    return undef unless $response && exists $response->{line};
    return $response->{line};
}

sub addhistory {
    my ($self, $line) = @_;
    
    $self->_send_command({
        cmd => 'addhistory',
        line => $line
    });
    
    return 1;
}

sub completion_function {
    my ($self, $func) = @_;
    
    $completion_func = $func;
    
    $self->_send_command({
        cmd => 'set_completion',
        has_completion => $func ? 1 : 0
    });
    
    return $func;
}

sub completion_matches {
    my ($self, $text, $line, $start, $end) = @_;
    
    # Call the Perl completion function
    if ($completion_func) {
        $completion_word = $text;
        @completion_matches = $completion_func->($text, $line, $start, $end);
        
        # Send matches to server
        $self->_send_command({
            cmd => 'set_matches',
            matches => \@completion_matches
        });
    }
    
    return @completion_matches;
}

sub ornaments {
    my ($self, $term, $normal, $underline, $boldface) = @_;
    
    $self->_send_command({
        cmd => 'ornaments',
        term => $term,
        normal => $normal,
        underline => $underline,
        boldface => $boldface
    });
    
    return (undef, undef, undef, undef);
}

sub DESTROY {
    my $self = shift;
    
    # Close socket
    if ($client_socket) {
        $self->_send_command({ cmd => 'exit' });
        close($client_socket);
        $client_socket = undef;
    }
    
    # Kill server process
    if ($server_pid) {
        kill('TERM', $server_pid);
        
        # Wait for process to exit
        my $waited = 0;
        while (waitpid($server_pid, WNOHANG) != -1 && $waited < 5) {
            sleep(1);
            $waited++;
        }
        
        # Force kill if still running
        if ($waited >= 5) {
            kill('KILL', $server_pid);
            waitpid($server_pid, 0);
        }
        
        $server_pid = undef;
    }
    
    # Clean up temp directory
    if ($socket_path && -e $socket_path) {
        unlink($socket_path);
    }
    
    return;
}

1;

__END__

=head1 NAME

Term::ReadLine::Remote - Remote readline implementation using a standalone server

=head1 SYNOPSIS

    use Term::ReadLine;
    my $term = Term::ReadLine->new('program_name');
    
    # The constructor will start a readline server process
    # and communicate with it via a Unix domain socket
    
    # Use it like any other Term::ReadLine implementation
    my $line = $term->readline('Enter something: ');
    $term->addhistory($line) if $line;
    
    # Completion works too
    $term->completion_function(sub {
        my ($text, $line, $start, $end) = @_;
        return grep { /^$text/ } qw(apple banana cherry date);
    });

=head1 DESCRIPTION

Term::ReadLine::Remote solves the "there can be only one readline" problem 
by moving the actual readline implementation to a separate process. This allows 
multiple readline instances to coexist, which is particularly useful for 
debugging applications that use readline themselves.

The module starts a C-based server process that links with libreadline and
communicates with the Perl application via a Unix domain socket. All readline
functionality including history, completion, and key bindings works as expected.

=head1 REQUIREMENTS

This module requires the readline-server binary to be built and available in
your PATH or specified via the READLINE_SERVER_BIN environment variable.

=head1 AUTHOR

Your Name <your.email@example.com>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
