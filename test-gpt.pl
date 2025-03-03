#!/usr/bin/perl
# vim: ts=2 sw=2 ft=perl
eval 'exec perl -x -wS $0 ${1+"$@"}'
  if 0;
$|++;
use common::sense;
use autodie;
use Nobody::Util;
use Snatcher;
our(@VERSION) = qw( 0 1 0 );

use AI::Conv;
use AI::Transact qw(transact);
my $file = path("test-gpt.jwrap");
my $conv = AI::Conv->new($file);
my $text = "Say goodnight, gracie!";
my $response = transact($conv,$text);
ddx($response);

