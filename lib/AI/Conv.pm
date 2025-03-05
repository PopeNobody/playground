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
sub check {
  my ($self)=shift;
  die "check: self is null" unless defined($self);
  die "check: not blessed" unless blessed($self);
  die "check: not blessed right" unless $self->isa("AI::Conv");
  my ($file)=$self->{file};
  die "check: file is null" unless defined($file);
  die "check: file is not blessed" unless blessed($file);
  die "check: file is not blessed right" unless($file->isa("Path::Tiny"));
  for(@{$self->{msgs}}){
    die "check: msg is not a msg" unless $_->isa("AI::Msg");
  };
  return $self;
};
sub new {
  my ($class, $file) = ( shift, shift);
  ($class) = ( ref($class) || $class );
  die "file is required" unless ref($file) and $file->isa('Path::Tiny');
  $file=$file->absolute,
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
    my $path=path("etc/system-message.md");
    ddx( { path=>$path } );
    my $msg = AI::Msg->new("system", "system", $path);
    ddx( { "ref(\$msg)"=>ref($msg) } );
    $self->add($msg);
  }

  return $self->check();
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
  say STDERR "[", join(", ",map { ref } @$jwrap), "]";

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
  my $last=pop(@$data);
  foreach my $raw (@$data) {
    my $msg=AI::Msg->from_jwrap($raw);
    $self->add($msg);
  }
  $last=AI::Msg->new($last);
  $self->add($last);
  return $self;
}

sub add {
  my ($self, $msg) = @_;
  confess "add should be called with an AI::Msg object" 
  unless safe_isa($msg,"AI::Msg");

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
