#!/usr/bin/perl
# vim: ts=2 sw=2 ft=perl
eval 'exec perl -x -wS $0 ${1+"$@"}'
  if 0;
$|++;
use common::sense;
use autodie;
use Nobody::Util;
our(@VERSION) = qw( 0 1 0 );

for(sort map { split } qx(find t -type f -name '*.t')){
  say;
  open(STDIN,"-|","perl",$_);
  chomp(@_=<STDIN>);
  no autodie 'close';
  say STDERR "$_ failed" unless close(STDIN);
  say for @_;
};
