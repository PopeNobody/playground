#!/usr/bin/perl
# vim: ts=2 sw=2 ft=perl
eval 'exec perl -x -wS $0 ${1+"$@"}'
  if 0;
$|++;
use common::sense;
use autodie;
our(@VERSION) = qw( 0 1 0 );
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
      return \%res if sysopen($res{fh},$res{fn},Fcntl::O_EXCL());
    };
  };
};
ddx( { func=>serial_maker("file%04d.txt",10000)});
use Nobody::Util;
$DB::single=$DB::single=1;
my $gen=serial_maker("file%-02.txt",10);
use Data::Dumper;
my ($res);
while(defined($res=gen->())){
  my $txt=Dumper($res);
  $gen->{fh}->say($txt);
  print STDERR $txt;
};

  
