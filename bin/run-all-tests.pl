#!/usr/bin/perl
# vim: ts=2 sw=2 ft=perl
eval 'exec perl -x -wS $0 ${1+"$@"}'
  if 0;
$|++;
use common::sense;
use autodie;
use Nobody::Util;
use Path::Tiny;
our(@VERSION) = qw( 0 1 0 );

my ($logdir) = path("log")->absolute;
my @failed;
open(my $save, ">&STDERR");
for(sort map { path($_) } map { split } qx(find t -type f -name '*.t')){
  say;
  my ($base) = $_->basename("*.t");
  my ($log) = $logdir->mkdir->child($base.".log");
  open(STDOUT,">",$log);
  open(STDERR,">&STDOUT");
  open(STDIN,"-|","perl",$_);
  chomp(@_=<STDIN>);
  no autodie 'close';
  next if close(STDIN);
  push(@failed,$log);
  $save->say("$_ failed");
} continue {
  open(STDIN,"</dev/null");
  open(STDOUT,">&".fileno($save));
  open(STDERR,">&".fileno($save));
};
exit(0) unless @failed;
open(STDERR,">&".fileno($save));
open(STDOUT,">&STDERR");
for( @failed ) {
  say "$_ failed";
  say $_->slurp;
};
exit(1);
