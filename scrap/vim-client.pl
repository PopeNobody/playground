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
die "usage vim-client.pl <args for vim>" unless @ARGV;
die "no server exists" unless -e $addr;
my $start=time;
sub running {
  return time-$start-1;
};
for(;;) {
  $sock= IO::Socket::UNIX->new(
    Peer=>$addr
  );
  last if defined $sock;
  STDERR->say("waiting");
  sleep(1);
};
for(@ARGV){
  s{\n}{\\n};
  $sock->say($_);
};
$sock->say("");
do {
  $_=<$sock>;
} while(!m{\S});
print "result: $_";
exit($_);
