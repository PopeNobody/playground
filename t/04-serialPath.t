#!/usr/bin/perl
# vim: ts=2 sw=2 ft=perl
eval 'exec perl -x -wS $0 ${1+"$@"}'
  if 0;
$|++;
{
  package IO::File;
  sub dbg{};
};
use common::sense;
use autodie;
our(@VERSION) = qw( 0 1 0 );
use lib "lib";
use Nobody::Util;
use Data::Dumper;
use Fcntl;
use Fcntl qw( :Fcompat );
use AI::Util;
use Carp qw(confess);

my $gen=serial_maker("t/tmp/file%08s.txt",10);
my ($res);
while(defined($res=$gen->())){
  my $txt=Dumper($res);
  my $XXX=$gen->();
  ddx($XXX);
};

  
