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

sub serial_maker($$) {
  my ($fmt)=shift;
  my ($max)=shift;
  my ($num)=0;
  return sub {
    local($_);
    my (%res)=( fh=>undef, fn=>undef );
    for(;;){
      return undef if($num>$max);
      $res{fn}=sprintf($fmt,$num++);
      no autodie 'sysopen';
      if(sysopen($res{fh},$res{fn},Fcntl::CREAT|Fcntl::O_EXCL())){
        ddx(\%res);
        return \%res 
      };
    };
  };
};
my $gen=serial_maker("file%-02.txt",10);
my ($res);
while(defined($res=$gen->())){
  my $txt=Dumper($res);
  my $XXX=$gen->();
  ddx($XXX);
};

  
