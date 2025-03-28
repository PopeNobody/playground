#!/usr/bin/perl
# vim: ts=2 sw=2 ft=perl
eval 'exec perl -x -wS $0 ${1+"$@"}'
  if 0;
$|++;
use common::sense;
use autodie;
use Nobody::Util;
our(@VERSION) = qw( 0 1 0 );
use IO::Socket::UNIX;
my $sock;
my $addr = "$ENV{PWD}/vim-server";
ddx([$addr]);
if(-e $addr) {
  say "socket exists";
  eval {
    $sock= IO::Socket::UNIX->new( Peer=>$addr);
  };
  warn pp( \$@ ) if $@;
  die "server exists" if(defined($sock));
  unlink $addr;
};
$sock = IO::Socket::UNIX->new(
  Listen=>5,
  Local=>$addr
);

while(1) {
  my $sock=$sock->accept();
  my (@argv) = "vim";
  while(1) {
    $_=<$sock>;
    die "incomplete message" unless defined;
    last if $_ eq "\n";
    chomp;
    push(@argv,$_);
  };
  die "$@" if "$@";
  for(@argv) {
    say pp($_);
  };
  system("tmux select-pane $ENV{TMUX_PANE}");
  system(@argv);
  $sock->print($?);
};

