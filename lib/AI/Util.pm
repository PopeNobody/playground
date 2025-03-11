#!/usr/bin/perl

package AI::Util;
use lib "lib";
use AI::TextProc;
use Carp qw(confess);
use Path::Tiny;
use POSIX qw(strftime mktime );
require Exporter;
our(@ISA)=qw(Exporter);
our(@EXPORT)=qw( pp format serial_maker path cal_loc  );

sub format;
*format=\&AI::TextProc::format;

sub pp {
  return line_dump(@_);
};
sub serdate(;$)
{
  my $time=@_ ? $_[0] : time;
  return strftime("%Y%m%d-%H%M%S", gmtime($time));
}
sub call_loc {
  my ( $pack, $file, $line ) = __PACKAGE__;
  while( $pack eq __PACKAGE ) {
    ($pack,$file,$line)=caller;
  };
  return $file, $line;
};
sub ppx {
  return join(":",call_loc,pp(@_));
};
sub dd {
  print STDOUT pp;
};
sub ddx {
  print STDOUT ppx;
};
sub ee {
  print STDERR pp;
};
sub eex {
  print STDERR ppx;
};

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


1;
