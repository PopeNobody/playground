package AI::Conv;

use strict;
use warnings;
use lib 'lib';
use AI::Msg;
use Storable qw(nstore retrieve);
use Nobody::Util;
use builtin qw(blessed);
use Nobody::JSON;
use Path::Tiny;
use Data::Dumper;
use Carp qw(confess);
use common::sense;
sub new {
  my ($class, $file) = ( shift, shift);
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

sub save_jwrap {
  my ($self) = @_;
  my $file = $self->{file};
  $file->parent->mkdir;
  $file->spew(encode_json($self->as_jwrap));
  return $self;
}

sub load_jwrap {
  my ($self) = @_;
  my ($file) = $self->{file};
  my $json=$file->slurp;
  my $data = decode_json($json);
  foreach my $msg (@$data) {
    $DB::single=1;
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
