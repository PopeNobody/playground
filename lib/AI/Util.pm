package AI::Util;
use lib "lib";
use AI::TextProc;
use Carp qw(confess);
use Data::Dumper;
use FindBin qw($Bin);
use JSON::PP;
use POSIX qw(strftime mktime );
use Path::Tiny;
require Exporter;
our(@ISA)=qw(Exporter);
our(@EXPORT)=qw( 
  cal_loc decode_json encode_json false format
  path safe_isa serdate serial_maker
  true qquote randomize

  pp ppx dd ddx ee eex

  $Bin $Pre $Script
);
sub randomize(@) {
  my (@list)=splice(@_);
  while(@list){
    push(@_,splice(@list,rand(@list),1));
  };
  return @_;
};
*qquote=*Data::Dumper::qquote;
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

sub serial_maker(%) {
  my (%arg)=%{$_[0]};
  ddx(\%arg);
  my ($fmt)=$arg{fmt}//die "format is required";
  my ($max)=$arg{max}//1000;
  my ($min)=$arg{min}//0;
  my ($dir)=!!$arg{dir};
  my ($num)=$min;
  return sub {
    local($_);
    my (%res)=( fh=>undef, fn=>undef );
    for(;;){
      return undef if($num>=$max);
      ($res{fn}=path(sprintf($fmt,$num)));
      $res{fn}->parent->mkdir;
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
  local($_);
  eval {
    ($_)=$json->encode(@_);
  };
  return $_ if defined;
  ddx(\@copy);
  die join("\n\n",$@,pp(@copy));
};
sub decode_json {
  local($_);
  eval {
    ($_)=$json->decode(@_);
  };
  return $_ if defined;
  die  join("\n\n",$@,pp(@copy));
};
{
  package Path::Tiny;
  sub bak {
    return shift->suf(".bak");
  };
  sub sav {
    return shift->suf("sav");
  };
  sub suf {
    local($self)=shift;
    my($suf)=shift;
    for(shift) {
      return path("$_$suf");
    };
  };
}
1;
