package AI::Util;
use lib ".";
use Snatcher;
use Carp qw(confess);
use FindBin qw($Bin);
use JSON::PP;
use Path::Tiny;
use POSIX qw(strftime mktime );
use Scalar::Util qw(blessed);
use Text::Wrap qw(wrap $columns );
use common::sense;
use Data::Dumper::Concise;
BEGIN {
  *qquote=*Data::Dumper::qquote;
  *true=*JSON::true;
  *false=*JSON::false;
};

use Exporter qw(import);
our(@ISA) = qw(Exporter);
our(@EXPORT)=qw( 
  cal_loc decode_json encode_json false find_script
  path safe_isa serdate serial_maker maybe_run_script
  true qquote randomize safe_can

  pp ppx dd ddx ee eex

  text_wrap

  $Bin $Pre $Script
);
sub randomize(@) {
  my (@list)=splice(@_);
  while(@list){
    push(@_,splice(@list,rand(@list),1));
  };
  return @_;
};
sub safe_can {
  my ($obj,$mth) = splice(@_);
  for($obj) {
    return 0 unless defined;
    return 0 unless ref;
    return 0 unless blessed($obj);
    return 0 unless $_->can($mth);
    return 1;
  };
};
sub safe_isa {
  my ($obj,$cls) = splice(@_);
  for($obj) {
    return 0 unless defined;
    return 0 unless ref;
    return 0 unless blessed($obj);
    return 0 unless $_->isa($cls);
    return 1;
  };
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
sub pp {
  return Dumper(@_);
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
our(@copy);
sub encode_json($) {
  local($_);
  my($copy)=pp(\@_);
  eval {
    ($_)=$json->encode(@_);
  };
  return $_ if defined;
  die join("\n\n",$@,$copy);
};
sub decode_json {
  local($_);
  my($copy)=pp(\@_);
  eval {
    ($_)=$json->decode(@_);
  };
  return $_ if defined;
  die  join("\n\n",$@,$copy);
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
    my($self)=shift;
    my($suf)=shift;
    return path("$self.$suf");
  };
}
sub text_wrap {
  local(@_)=@_;
  local($columns)=70;
  my $i=0;
  while($i<@_){
    local(*_)=\$_[$i];
    if(!defined) {
      splice(@_,$i,1);
    } elsif(blessed($_) and $_->can("slurp")){
      splice(@_,$i,1,$_->slurp);
    } elsif (ref($_) eq 'ARRAY' ) {
      splice(@_,$i,1,@$_);
    } elsif (m{\n}) {
      splice(@_,$i,1,split(m{\n}));
    } else {
      $i++;
    };
  };
  die "still refs in \@_" if 0!=(grep {ref($_)} @_);
  local($_)=join("\n",@_);
  # fixme.  We should find lists and such in markup,
  # and make sure there is a blank line after.
  $_=wrap("","",$_);
  if(wantarray){
    return split(m{\n});
  } else {
    return $_;
  };
};
sub find_script($){
  local($_)=shift;
  s{^\n+}{}sm;
  s{\n+$}{};
  local(@_)=split(m{\n});
  my (@i) = grep { $_[$_] =~ m{^```} } 0 .. @_-1;
  ddx([ @i, [ @_-1 ]]);
  ddx([[ @i == 2 ], [ $i[0] == 0 ], [ $i[1] == @_-1 ]] );
  if(@i == 2 && $i[0] == 0 && $i[1] == @_-1 ) {
    shift(@_); pop(@_);
    say STDERR "found ticks\n";
  };
  if(@_[0] =~ m{^#!}){
    say STDERR "found shebang\n";
    return join("\n",@_);
  } else {
    return ();
  };
};
sub maybe_run_script($$$){
  die (
    "usage: maybe_run_script( [ response, mod_id, conv ] )" 
  ) unless @_ ==1;
  my ($text,$mod_id,$conv)=(shift,shift,shift);
  my ($script)=find_script($text);
  my ($send);
  if(defined($script)){
    path("script.pl")->spew($script);
    system("capture -f script.log -- perl script.pl");
    $text=join("\n",$conv,"SYSTEM:",
      "  script found:",
      join("\n",map { "    $_" } split(m{\n},$script)),
      "  output produced:",
      join("\n",map { "    $_" } path("script.log")->lines()),
    );
    $send=1;
  } else {
    $text=text_wrap($text);
    $conv=join("\n",$conv,uc("$mod_id:"),join("\n  ",m{\n}));
    $send=0;
  };
  return [ $send, $conv ];
};
1;
