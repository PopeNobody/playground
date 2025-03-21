#!/usr/bin/perl

package AI::Util;
use FindBin qw($Bin);
our($Pre);
BEGIN {
  for(map { "$_" } $Bin){
    s{/(bin|sbin|t)$}{};
    $Pre="$_";
  };
};
use AI::TextProc;
use Carp qw(confess);
use Path::Tiny;
use POSIX qw(strftime mktime );
use JSON::PP;
use Data::Dumper;
require Exporter;
our(@ISA)=qw(Exporter);
our(@EXPORT)=qw( 
  cal_loc decode_json encode_json false format
  path safe_isa serdate serial_maker
  true

  pp ppx dd ddx ee eex

  $Bin $Pre $Script
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
  my ($i)=0;
  my ( $pack, $file, $line ) = caller($i);
  while( $pack eq __PACKAGE__) {

    ($pack,$file,$line)=caller(++$i);
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

sub serial_maker($$;$) {
  my ($fmt)=shift;
  my ($max)=shift;
  my ($dir)=map { !!$_ } shift;
  my ($num)=0;
  return sub {
    local($_);
    my (%res)=( fh=>undef, fn=>undef );
    for(;;){
      return undef if($num>$max);
      ($res{fn}=path(sprintf($fmt,$num)))->parent->mkdir;
      no autodie qw(sysopen mkdir);
      if($dir) {
        if(mkdir($res{fn})){
          return \%res;
        } elsif ( $!{EEXIST} ) {
          ++$num;
        } else {
          confess "mkdir:$res{fn}:$!";
        };
      } else {
        if(sysopen($res{fh},$res{fn},Fcntl::O_CREAT|Fcntl::O_EXCL())){
          eex(\%res);
          return \%res 
        } elsif ( $!{EEXIST} ) {
          ++$num;
        } else {
          confess "sysopen:$res{fn}:$!";
        };
      }
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
