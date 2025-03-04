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
our(@keys);
BEGIN {
  @keys=qw(role name text);
};
sub mayslurp {
  local($_)=shift;
  return $_ unless blessed($_);
  return $_ unless $_->can("slurp");
  return $_->slurp;
};
sub check {
  my $hash=shift;
  for(@keys) {
    confess "$_ must not be null" unless defined $hash->{$_};
  };
};
sub new {
    my ($class) = shift;
    $_ = (ref || $_) for $class;
    die "class must be defined" unless defined $class;
    my $self = bless({},$class);
    for(@keys) {
      $self->{$_}=shift;
    };
    for($self->{text}){
      ddx($_);
      @_=flatten($_);
      ddx(\@_);
      @_=map { mayslurp($_) } @_;
      ddx(\@_);
      $_=join("\n",@_);
      ddx($_);
      $_=wrap("","",$_);
      ddx($_);
    };
    bless $self, $class;
}

sub from_jwrap {
    my ($class, $data) = @_;
    confess "$class must never be null" unless defined $class;
    confess "$data must not be mull" unless defined $data;
    for(qw(role name text)) {
      confess "data->{$_} not defined" unless defined $data->{$_};
    };
    return $class->new($data->{role}, $data->{name}, $data->{text});
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
