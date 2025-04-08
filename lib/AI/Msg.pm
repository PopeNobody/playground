package AI::Msg;
use lib 'lib';
use AI::Config;
use AI::Util;
use Carp qw(confess carp croak cluck);
use Data::Dumper;
use MIME::Types;
use Scalar::Util qw(blessed);
use Time::HiRes qw(time);
use common::sense;
use strict;
use warnings;

use overload '""' => sub { confess "don't stringify me bro!"; };

our(@required_keys, @optional_keys);
BEGIN {
  @required_keys = qw(role name text);
  @optional_keys = qw(type timestamp);
};

our $MIME_TYPES = MIME::Types->new();
our %INTERPRETER_MAP;

sub check {
  my $hash=shift;
  for(@required_keys) {
    confess "$_ must not be null" unless defined $hash->{$_};
    confess "$_ must have length" unless length $hash->{$_};
  };
  # Initialize optional fields with defaults if not set
  $hash->{type} ||= 'text/plain';
  $hash->{timestamp} ||= time();
  $hash;
};

# Helper function to detect script type from shebang line
sub _detect_script_type {
  (my $text,my @text) = split(m{\n},shift); 
#      ddx( { line=>$text, rest=>\@text } );
  # Default to plain text if no shebang
  return 'text/plain' unless $text =~ /^#!(.+)$/;
  my $shebang = $1;
  my $ext = 'x';  # default executable extension
  
  # Check for each known interpreter
  foreach my $interp (keys %INTERPRETER_MAP) {
    if ($shebang =~ /\b$interp\b/) {
      $ext = $INTERPRETER_MAP{$interp};
      last;
    }
  }
  
  # Look up MIME type for the extension
  my $mime_obj = $MIME_TYPES->type(ext => $ext);
  
  # Return the MIME type if found, otherwise use a sensible default
  if ($mime_obj) {
    return $mime_obj->type;
  } elsif ($ext eq 'x') {
    return 'application/x-executable';
  } else {
    # If we identified an interpreter but MIME::Types doesn't have a mapping,
    # use a well-formed MIME type based on the extension
    return "application/x-$ext";
  }
}
sub name {
  my ($self)=shift;
  $self->{name};
}
sub role {
  my ($self)=shift;
  $self->{role};
}
sub text {
  my ($self)=shift;
  $self->{text};
}
sub new {
  my ($class) = shift;
  $_ = (ref || $_) for $class;
  die "class must be defined" unless defined $class;
  my $self = bless({},$class);
  
  # Extract values based on param type
  if(ref($_[0]) eq 'HASH'){
    #dbg STDERR "data from HASH: ", pp($_[0]);
    # Required keys
    foreach my $k (@required_keys) {
      $self->{$k} = $_[0]->{$k};
      confess "Required field $k missing in hash" unless defined $self->{$k};
    }
    # Optional keys
    foreach my $k (@optional_keys) {
      $self->{$k} = $_[0]->{$k} if defined $_[0]->{$k};
    }
  } else {
    #dbg STDERR "data from \@_: (@_)";
    
    # We expect exactly three required positional parameters, plus optional ones
    confess "Expected at least 3 parameters (role, name, text)" 
      unless @_ >= 3;
    
    # Assign the three required positional parameters
    @{$self}{@required_keys} = splice(@_, 0, 3);
    
    # Handle optional params as key/value pairs if present
    while (@_ >= 2) {
      my $key = shift;
      my $val = shift;
      $self->{$key} = $val if grep { $_ eq $key } @optional_keys;
    }
    
    # Verify required fields are defined
    foreach my $k (@required_keys) {
      confess "Required field $k is undefined in" , Dumper($self)
      unless defined $self->{$k};
    }
  }
  
  # Trim whitespace from name and role
  for(qw(name role text)){
    $self->{$_} =~ s{^\s+}{};
    $self->{$_} =~ s{\s+$}{};
  };
  
  # Set timestamp if not already set
  $self->{timestamp} ||= time();
  
  # Set default type if not set
  $self->{type} ||= 'text/plain';
  
  # Auto-detect scripts and assign specific MIME types
  if ($self->{type} eq 'text/plain' && $self->{text} =~ /^#!/m) {
    $self->{type} = _detect_script_type($self->{text});
  }
  # Don't reformat scripts.
  if($self->{type} eq "text/plain") {
    for($self->{text}){
      $_=AI::TextProc::format($_);
    };
  };
  
  
  return $self->check;
}
sub type {
  my($self)=@_;
  return $self->{type};
};
sub run {
  my ($self)=shift;
  if( $self->{type} eq "text/plain" ) {
    die "one does not simply RUN plain text!";
  };
}
sub from_jwrap {
  my ($class, $data) = @_;
  
  # Handle text array from JSON
  if (ref($data->{text}) eq 'ARRAY') {
    $data->{text} = join("\n", @{$data->{text}});
  }
  
  return $class->new($data);
}

sub as_json {
  my ($self) = @_;

  return encode_json({
      role => $self->{role},
      content => $self->{text}
    });
}

sub as_jwrap {
  my ($self) = @_;
  
  my $result = {
    role => $self->{role},
    name => $self->{name},
    text => [ split(m{\n}, $self->{text}) ],
  };
  
  # Add optional fields if present
  $result->{type} = $self->{type} if defined $self->{type};
  $result->{timestamp} = $self->{timestamp} if defined $self->{timestamp};
  
  return $result;
}
BEGIN {
  # Map interpreter commands to file extensions
  %INTERPRETER_MAP = (
    'perl'    => 'pl',
    'python'  => 'py',
    'python2' => 'py',
    'python3' => 'py',
    'bash'    => 'sh',
    'sh'      => 'sh',
    'zsh'     => 'sh',
    'ksh'     => 'sh',
    'dash'    => 'sh',
    'ruby'    => 'rb',
    'node'    => 'js',
    'nodejs'  => 'js',
    'php'     => 'php',
    'Rscript' => 'r',
    'lua'     => 'lua',
    'awk'     => 'awk',
    'sed'     => 'sed',
    'tcl'     => 'tcl',
    'tclsh'   => 'tcl',
    'wish'    => 'tcl',
  );
}
1;
