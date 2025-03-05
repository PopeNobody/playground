package AI::Msg;

use strict;
use warnings;
use lib 'lib';
use Nobody::Util;
use Path::Tiny;
use Data::Dumper;
use Carp qw( confess carp croak cluck );
use common::sense;
use Scalar::Util qw(blessed);
use Text::Wrap qw(wrap $columns );
$columns=30;
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
    confess "$_ must lave length" unless length $hash->{$_};
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
  ddx({map { $_, eval $_ } 'ref($_[0])'});
  if(ref($_[0]) eq'HASH'){
    say STDERR "data from HASH: ", pp($_[0]);
    $self->{$_}=$_[0]->{$_} for(@keys);
  } else {
    say STDERR "data from \@_: (@_)";
    $self->{$_}=shift for @keys;
  };
  @_=grep { !$deflen->($_) } @keys;
  die "empty values for @_" if @_;
  for(qw(name role)){
    $self->{$_} =~ s{^\s+}{};
    $self->{$_} =~ s{\s+$}{};
  };
  for($self->{text}){
    @_=$_;
    @_=map { flatten($_) } @_;
    @_=map { mayslurp($_) } @_;
    $_=join("\n",@_);
    s{^\s+}{};
    s{\s+$}{};
    $_=wrap("","",$_);
    ddx(\@_);
  };
  $self->check;
}

sub from_jwrap {
  goto \&new;
}

sub as_jwrap {
    my ($self) = @_;
    return {
        role => $self->{role},
        name => $self->{name},
        text => [ split(m{\n}, $self->{text}) ],
    };
}

1;
