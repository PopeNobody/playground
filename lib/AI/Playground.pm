#!/usr/bin/perl
# vim: ts=2 sw=2 ft=perl
eval 'exec perl -x -wS $0 ${1+"$@"}'
  if 0;
$|++;
package AI::Playground;
use common::sense;
use autodie;
use AI::Util;
use Path::Tiny;
use AI::Config qw(:all);
use AI::Conv;
use AnyEvent::Socket;;
use AnyEvent::Handle;;
our(@VERSION) = qw( 0 1 0 );

our(%self);
sub new {
  my ($class)=shift;
  my (%self)=@_;
  my ($self)\%self;
  $self{conv}||=AI::Conv->new;
  bless($self,$class);
};
sub run {
  AE::cv->recv;
}
sub mk_sock {
  tcp_server undef, $port, sub {
    warn "got connection\n";
    warn "but nothing else is implemented\n";
  };
};
1;
