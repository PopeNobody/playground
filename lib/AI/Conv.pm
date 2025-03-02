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
  die "file is required" unless $file->isa('Path::Tiny');
  my $self={
    file => $file,
    msgs => [ ],
  };
  bless $self, $class;
  $self->add(AI::Msg->new("system", "system", path("etc/system-message.md")));
  return $self;
}

sub load_or_create {
  my ($class, $file) = @_;

  unless (-e $file) {
    say STDERR "File $file does not exist, creating new conversation.";
    return $class->new(path($file));
  }

  my $self;
  eval {
    $self = $class->load_jwrap($file);
  };
  if ($@) {
    die "Error loading conversation file $file: $@. Aborting to prevent data loss.";
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
  my ($class, $file) = @_;
  my $json=path($file)->slurp;
  my $data = decode_json($json);
  my $self = bless { file => path($file), msgs => [] }, $class;
  foreach my $msg (@$data) {
    $DB::single=1;
    my $ai_msg=AI::Msg->from_jwrap($msg);
    push @{$self->{msgs}}, $ai_msg;
  }

  use Data::Dumper;
  print Dumper($self);
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
