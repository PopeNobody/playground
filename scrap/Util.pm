#!/usr/bin/perl
# vim: ts=2 sw=2 ft=perl
#
package Nobody::Util;
our ( @EXPORT, @EXPORT_OK, @ISA );
use vars qw(@carp @pp);
use lib "/opt/lib/perl";
use Carp;
use Path::Tiny;
use Fcntl qw(:seek :mode);
BEGIN {
  @pp=qw( dd ddx ee eex pp ppx qquote quote );
  @carp=(sub{package Carp; return @EXPORT,@EXPORT_OK,@EXPORT_FAIL;})->();
};
{
  package main;
  use common::sense;
};
sub getfl(*) {
  my($fh)=shift;
  my($val);
  fcntl($fh,F_GETFL,$val);
  return $val;
};
sub setfl(*$) {
  my ($fh)=shift;
  my ($val)=shift;
  fcntl($fh,F_SETFL,$val);
};
sub nonblock {
  my ($fh)=shift;
  if(!@_ || shift) {
    setfl($fh,getfl($fh)|O_NONBLOCK);
  };
};
sub basename {
  my ($self)=shift;
  return () unless defined($self);
  $self=path($self) unless ref($self);
  $self->basename;
};
sub flatten {
  my $i=0;
  local(@_)=@_;
  while($i<@_) {
    for($_[$i]){
      if(ref($_) eq 'ARRAY') {
        splice(@_,$i,1,@{$_[$i]});
      } else {
        ++$i;
      };
    };
  };
  return @_;
};
sub safe_isa($$){
  my ($ref,$class) = @_;
  return 0 unless ref($ref);
  return 0 unless blessed($ref);
  return 0 unless $ref->isa($class);
  return 1;
};
sub dirname {
  my ($self)=shift;
  $self=path($self) unless ref($self);
  $self->dirname;
};
use Carp @carp;
use Nobody::PP @pp;
use FindBin;
use FindBin @FindBin::EXPORT_OK;
use List::Util;
use List::Util @List::Util::EXPORT_OK;
use Scalar::Util;
use Scalar::Util @Scalar::Util::EXPORT_OK;

BEGIN {
  push(@EXPORT_OK,@FindBin::EXPORT_OK);
  push(@EXPORT_OK,@Nobody::PP::EXPORT_OK);
  push(@EXPORT_OK, @carp, @pp, qw{
        WNOHANG avg class deparse dirname file_id getcwd matrix max vcmp
        maybeRef min mkdir_p mkref open_fds pasteLines path serdate spit
        spit_fh suck suckdir sum uniq setfl getfl nonblock flatten
        safe_isa serial_path
        }
      );
  push(@EXPORT_OK, @Scalar::Util::EXPORT_OK);
  push(@EXPORT_OK, @List::Util::EXPORT_OK);
  @EXPORT_OK = grep { !m{^(all|uniq)} } @EXPORT_OK;
  push(@EXPORT_OK, @carp, @pp, basename,
    qw( sum avg max min mkdir_p
    suckdir suck spit getcwd ));
  push(@EXPORT_OK,
    qw( pasteLines serdate class mkref open_fds deparse maybeRef ),
    qw( file_id WNOHANG uniq matrix dirname )
  );
}
use strict;
use warnings;
use feature qw(say);
use autodie;
use POSIX qw(strftime mktime );
use Env qw( $HOME $PWD @PATH );
use lib "/opt/lib/perl";
use POSIX ":sys_wait_h";
BEGIN {
  @EXPORT=@EXPORT_OK;
  @ISA=qw(Exporter);
  require Exporter;
  sub import {
    #warn(pp([caller]));
    goto &Exporter::import;
  };
}
sub mkdir_p($;$);
sub QX {
  if(!defined(wantarray)) {
    QX(@_);
    return;
  } elsif( !wantarray ) {
    return join("", "@_");
  } else {
    open(local *STDIN,"-|",@_);
    local(@_)=<STDIN>;
    close(STDIN);
    @_;
  }
};
sub mkdir_p($;$) {
  no autodie qw(mkdir);
  my ($dir,$mode)=@_;
  return 1 if -d $dir;
  $mode=0755 unless defined($mode);
  return 1 if mkdir($dir,$mode);
  die "mkdir:$dir:$!" unless $!{ENOENT};
  my (@dir) = split(m{/+},$dir);
  pop(@dir);
  mkdir_p(join("/",@dir),$mode);
  mkdir($dir,$mode); 
};
sub serial_path {
  local(@_)=@_;
  my $i;
  for($i=0;$i<@_;$i++) {
    if($_[$i] =~ m{^[1-9][0-9]*$}){
      last;
    };
  };
  die "no number found in serialPath(@_)" unless $i<@_;
  while(-e join("",@_) ){
    die "not found" unless $_[$i] < ++$_[$i];
  };
  return join("",@_);
};
sub getfds();
BEGIN {
  sub getfds() {
    opendir(my $dir,"/proc/self/fd");
    my $no = fileno($dir);
    while(readdir($dir)){
      print;
    };
    closedir($dir);
  };
};
sub matrix(){
  my $l;
  while(<>){
    my (@r) = split;
    for(scalar(@r)){
      $l=$_ if $l<$_;
    };
    push(@_,\@r);
  };
  @_;
};
sub open_fds(;$);
BEGIN {
  sub open_fds(;$) {
    my ($dn) = "/proc/self/fd/";
    if(@_ && $_[0]) {
      map { [ $_, readlink "$dn$_" ] } open_fds();
    } else {
      @_ = suckdir($dn);
      @_ = grep { -e } @_;
      @_ = grep { s{.*/}{} } @_;
#          opendir(my $dir,$dn);
#          local(@_)=readdir($dir);
#          close($dir);
#          @_ = grep { -e "$dn/$_" && $_ ne '.' && $_ ne '..' } @_;
    }
  };
  sub getcwd {
    return readlink("/proc/self/cwd");
  };
};
sub avg(@){
  return 0 unless @_;
  return sum(@_)/@_;
};
sub suckdir(@);
sub suckdir(@){
  return map { scalar(suckdir($_)) } @_ unless @_ == 1;
  local($_)=shift;
  die "undefined dirname" unless defined;
  for($_) {
    s{//+}{/}g;
    s{/+$}{};
  };
  if(length) {
    return grep { !m{/[.][.]?$} } glob("$_/* $_/.*");
  } else {
    return grep { s{^\./}{} } suckdir(".");
  };
}
use File::stat qw(:FIELDS);

sub file_id {
  die "useless use of file_id in void context" unless defined wantarray;
  local ($_)=shift;
  die "!defined" unless defined;
  stat($_);
  my $file_id=sprintf("%016x:%016x",$st_dev,$st_ino);
  say( "$_ => $file_id" );
  return $file_id;
};
sub suck(@){
  die("useless use of suck in void context") unless defined wantarray;
  local(@ARGV)=@_;
  local($/,$_,@_);
  $_=<ARGV>;
  if(wantarray) {
    return split(/\n/);
  } else {
    return $_;
  };
};
{
  package Null;
};
sub class($){
  return ref||$_||'undef' for shift;
};
sub pasteLines(@) {
  for(join("",@_)){
    s{\\\n?$}{}sm;
  }
  return join("\n",@_) unless wantarray;
  return @_;
}
sub spit_fh($@){
  my($fh)=shift;
  $fh->print(join("",@_));
};
sub spit($@){
  local($\,$/);
  my ($fn,$fh)=(shift);
  use autodie qw(open close);
  if($fn =~ m{^<}){
    die "error:  output file starts with <";
  } elsif ( $fn =~ m{^>} ) {
    # say nothing, act natural
  } else {
    $fn=">$fn";
  };
  open($fh,"$fn");
  spit_fh($fh,@_);
  close($fh);
};
sub maybeRef($) {
  carp "use class, not maybeRef";
  goto \&class;
};
sub vcmp {
  my ($a,$b) = (
    @_ == 2 ? (shift,shift) :
    @_ ? (undef, undef, warn "Warning:  vcmp wants 2 args or none") :
    ($a,$b)
  );

  my (@a)=split m{(\D+)}, $a;
  my (@b)=split m{(\D+)}, $b;
  no warnings;
  while( @a and @b and $a[0] eq $b[0] ) {
    shift @a;
    shift @b;
  };
  return 0 unless @a or @b;
  return @a <=> @b unless @a and @b;
  return $a[0] <=> $b[0] || $a[0] cmp $b[0];  
};
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
my @x=qw(sec min hour mday mon year wday yday isdst);
sub serdate(;$)
{
  my $time=@_ ? $_[0] : time;
  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($time);
  @_=($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
  return strftime("%Y%m%d-%H%M%S", @_);
}
our(%caller);
sub deparse {
  eval "use B::Deparse";
  die "$@" if "$@";
  my $deparse = B::Deparse->new("-p", "-sC");
  return join(' ', 'sub{', $deparse->coderef2text(\&func), '}');
};
#unless(caller){
#  use Carp;
#  sub test_date(;$) {
#    $,=" ";
#    $DB::single=1;
#    $DB::single=1;
#    my $time=time;
#    say $time;
#    my (@gm);
#    my $ser=serdate($time);
#    say $ser;
#    $_=$ser;
#    #    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = 
#    ($year,$mon,$mday,$hour,$min,$sec)=map{int($_)}
#    (m{^(\d\d\d\d)(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d)-gmt});
#    @_=( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst );
#    $year-=1900;
#    $mday++;
#    for(0 .. @_) {
#      my $idx="$_";
#      my $val=($_[$_]//-1);
#      my $tag=$x[$_];
#      #ddx([ $idx, $val, $tag ]);
#      #say $_, ($_[$_]//-1), ($x[$_]);
#    };
#    #ddx(\@_);
#  };
#  test_date;
#  exit(0);
#};
1;
=head1 NAME

Nobody::Util - Pretty printing of data structures

=head1 SYNOPSIS

This is a Lazy Bastard package that you probably don't want to use.
Nobody made it because Nobody is as lazy as he is.  It's full of
ugly hacks, but saves him time.

=cut

1;
