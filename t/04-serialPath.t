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
use Nobody::Util;
use Data::Dumper;
use Fcntl;
use Fcntl qw( :Fcompat );
use Carp qw(confess);

sub serial_maker($$) {
  my ($fmt)=shift;
  my ($max)=shift;
  my ($num)=0;
  return sub {
    local($_);
    my (%res)=( fh=>undef, fn=>undef );
    for(;;){
      return undef if($num>$max);
      ($res{fn}=path(sprintf($fmt,$num)))->parent->mkdir;
      no autodie 'sysopen';
      if(sysopen($res{fh},$res{fn},Fcntl::O_CREAT|Fcntl::O_EXCL())){
        eex(\%res);
        return \%res 
      } elsif ( $!{EEXIST} ) {
        ++$num;
      } else {
        confess "sysopen:$res{fh}:$!";
      };
    };
  };
};
my $gen=serial_maker("t/tmp/file%08s.txt",10);
my ($res);
while(defined($res=$gen->())){
  my $txt=Dumper($res);
  my $XXX=$gen->();
  ddx($XXX);
};

  
