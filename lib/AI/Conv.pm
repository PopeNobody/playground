package AI::Conv;

use strict;
use warnings;
use lib 'lib';
use AI::Msg;
use Storable qw(nstore retrieve);
use Nobody::Util;
use Scalar::Util qw(blessed);
use Nobody::JSON;
use Path::Tiny;
use Data::Dumper;
use Carp qw(confess);
use common::sense;
sub file {
  my ($self) = shift;
  my ($file) = $self->{file};
  $file;
};
sub new {
  my ($class, $file) = ( shift, shift);
  ($class) = ( ref($class) || $class );
  die "file is required" unless ref($file) and $file->isa('Path::Tiny');
  my $self={
    file => $file,
    msgs => [ ],
  };
  bless $self, $class;
  if (-e $file) {
    say STDERR "Loading AI::Conv from $file";
    $self->load_jwrap();
  } else {
    say STDERR "File $file does not exist, creating new conversation.";
    $self->add(AI::Msg->new("system", "system", path("etc/system-message.md")));
  }

  return $self;
}
sub file {
  my ($self)=shift;
  my ($file)=$self->{file};
  return $file;
};
sub save_jwrap {
  my ($self) = @_;
  my $file = $self->{file};
  $file->parent->mkdir;
  my $jwrap=$self->as_jwrap;
  print join(", ",map { ref } @$jwrap);

  $file->spew(encode_json($jwrap));
  return $self;
}

sub load_jwrap {
  my ($self) = @_;
  die "self must be defined" unless defined $self;
  die "self must be ref" unless ref($self);
  my ($file) = $self->{file};
  die "file must be defined" unless defined $file;
  die "file must be ref" unless ref($file);
  die "file must slurp" unless $file->can("slurp");
  my $json=$file->slurp;
  my $data;
  eval {
    $data  = decode_json($json);
  };
  die "$@ ($json)" if "$@";
  foreach my $msg (@$data) {
    push @{$self->{msgs}}, AI::Msg->from_jwrap($msg);
  }
  return $self;
}

sub add {
  my ($self, $msg) = @_;
  confess "add should be called with an AI::Msg object" 
  unless $msg->isa("AI::Msg");

  push @{$self->{msgs}}, $msg;
  $self->save_jwrap();
}

sub as_jwrap {
  my ($self) = @_;
  return [ map { $_->as_jwrap() } @{$self->{msgs}} ];
}

sub as_json {
  my ($self) = @_;
  my @standard_msgs;

  foreach my $msg (@{$self->{msgs}}) {
    push @standard_msgs, {
      role => $msg->{role},
      content => $msg->{text}
    };
  }

  return encode_json({
      messages => \@standard_msgs,
      model=>$ENV{OPENAI_API_MOD},
    });
}
1;
