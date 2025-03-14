#!/usr/bin/perl

package AI::Util;
use lib "lib";
use AI::TextProc;
use Carp qw(confess);
use Path::Tiny;
use POSIX qw(strftime mktime );
use JSON::PP;
use Data::Dumper;
require Exporter;
our(@ISA)=qw(Exporter);
our(@EXPORT)=qw( 
pp ppx dd ddx ee eex
format serial_maker path cal_loc decode_json encode_json
true false safe_isa
);

*true=*JSON::true;
*false=*JSON::false;
sub format;
*format=\&AI::TextProc::format;

sub safe_isa {
  my ($obj,$cls) = splice(@_);
  for($obj) {
    return 0 unless defined;
    return 0 unless ref;
    return 0 unless blessed;
    return 0 unless $_->isa($cls);
    return 1;
  };
};
sub pp {
  local ($Data::Dumper::Deparse)=1;
  local ($Data::Dumper::Terse)=1;
  return Dumper(@_);
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
  print STDOUT pp(@_);
};
sub ddx {
  print STDOUT ppx(@_);
};
sub ee {
  print STDERR pp(@_);
};
sub eex {
  print STDERR ppx(@_);
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

our ($json) = JSON::PP->new->ascii->pretty->allow_nonref->convert_blessed;
sub encode_json ($);
sub encode_json($) {
  my @copy=@_;
  local($_);
  eval {
    ($_)=$json->encode(@_);
  };
  return $_ if defined;
  ddx(\@copy);
  die join("\n\n",$@,pp(@copy));
};
sub decode_json {
  my @copy=@_;
  local($_);
  eval {
    ($_)=$json->decode(@_);
  };
  return $_ if defined;
  die  join("\n\n",$@,pp(@copy));
};


1;
