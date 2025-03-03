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
sub help {
  say "usage; $0 [ -f \$file ] [ -e ]";
  say "";
  say "   -f \$file: prompt from file \$file";
  say "";
  say "   -e edit first.  filename is still used, if provided";
};
while(($_=shift)ne'--'){
  if( $_ eq '-f') {
    $file=path(shift);
  } elsif ( $_ eq '-e' ) {
    $edit=1;
  } else {
    die "bad arg: $_";
  };
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

