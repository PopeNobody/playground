#!/usr/bin/perl
# vim: ts=2 sw=2 ft=perl
eval 'exec perl -x -wS $0 ${1+"$@"}'
  if 0;
$|++;
use common::sense;
use autodie;
use Nobody::Util;
our(@VERSION) = qw( 0 1 0 );

use AI::Transact;

my $text = "This is a test.  Please respond with 'Hello, World' if you recived this.   If you do not receive this, plase notify me via email.  :)";

