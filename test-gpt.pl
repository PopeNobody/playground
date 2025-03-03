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
use Getopt::WonderBra;
use AI::Conv;
use AI::Transact qw(transact);

@ARGV = getopt("f:e",@ARGV);
my $text = "Say goodnight, gracie!";
my ($edit,$file) = ( 0, undef );
while(($_=shift)ne'--'){
  if( $_ eq '-f') {
    $file=path(shift);
  } elsif ( $_ eq '-e' ) {
    $edit=true;    
};
if($edit) {
  $file//="prompt.txt";
  system("vi prompt.txt");
  die "edit session failed" if $?;
}
if(defined($file)){
  $text=$file->slurp;
};
$file = path("test-gpt.jwrap");
my $conv = AI::Conv->new($file);
my $response = transact($conv,$text);
ddx($response);

