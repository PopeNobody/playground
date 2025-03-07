package AI::Msg;

use strict;
use warnings;
BEGIN {
  use lib "$ENV{PWD}/lib";
};
use Nobody::Util;
use Path::Tiny;
use Data::Dumper;
use Carp qw(confess carp croak cluck);
use AI::TextProc;
use common::sense;
use Scalar::Util qw(blessed);
our(@keys);
BEGIN {
  @keys=qw(role name text);
};

sub mayslurp {
  local($_)=shift;
  say STDERR "checking blessed";
  return $_ unless blessed($_);
  say STDERR "checking can slurp";
  return $_ unless $_->can("slurp");
  say STDERR "calling slurp";
  return $_->slurp;
};

sub check {
  my $hash=shift;
  for(@keys) {
    confess "$_ must not be null" unless defined $hash->{$_};
    confess "$_ must have length" unless length $hash->{$_};
  };
  $hash;
};

my $deflen=sub {
  local($_)=shift;
  return 0 unless defined;
  return 0 unless length;
  1;
};

sub new {
  my ($class) = shift;
  $_ = (ref || $_) for $class;
  die "class must be defined" unless defined $class;
  my $self = bless({},$class);
  
  # Keep debugging output
  ddx({map { $_, eval $_ } 'ref($_[0])'});
  
  # Extract values based on param type
  if (ref($_[0]) eq 'HASH') {
    say STDERR "data from HASH: ", pp($_[0]);
    foreach my $k (@keys) {
      $self->{$k} = $_[0]->{$k};
      confess "Required field $k missing in hash" unless defined $self->{$k};
    }
  } else {
    say STDERR "data from \@_: (@_)";
    
    # We expect exactly three positional parameters: role, name, text
    confess "Expected exactly 3 parameters (role, name, text), got " . scalar(@_) 
      unless @_ == 3;
    
    # Assign the three positional parameters
    @{$self}{@keys} = @_;
    
    # Verify all are defined
    foreach my $k (@keys) {
      confess "Required field $k is undefined" unless defined $self->{$k};
    }
  }
  
  # Trim whitespace from name and role
  for(qw(name role)){
    $self->{$_} =~ s{^\s+}{};
    $self->{$_} =~ s{\s+$}{};
  };
  
  # Process text with intentional duplication of $DB::single
  for($self->{text}){
    $DB::single=$DB::single=1;
    $_=AI::TextProc::format($_);
  };
  
  return $self->check;
}

sub from_jwrap {
  my ($class, $data) = @_;
  
  # Handle text array from JSON
  if (ref($data->{text}) eq 'ARRAY') {
    $data->{text} = join("\n", @{$data->{text}});
  }
  
  return $class->new($data);
}

sub as_jwrap {
  my ($self) = @_;
#      
  return {
    role => $self->{role},
    name => $self->{name},
    text => [ split(m{\n}, $self->{text}) ],
  };
}

1;
