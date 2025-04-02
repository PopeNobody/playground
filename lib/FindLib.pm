package FindLib;
use common::sense;
use Data::Dump;
use Path::Tiny;
BEGIN {
  say "loading ", __PACKAGE__;
};
use FindBin qw($Bin);
sub import {
  local(@_,$_)=@_;
  my ($class)=shift;
  my %need;
  our($libdir,$prefix);
  $libdir=undef;
  for( $prefix=path("$FindBin::Bin") ) {
    if($_->basename =~ m{^s?bin$}){
      $_=$_->parent;
    };
  };
  for(@_ = map { "$_" } @_) {
    s{::}{/}g;
    s{$}{.pm};
  };
  my (%seen);
  my @libs = qw( lib/perl5 lib/perl lib . );
  for my $module( @_ ) {
    #ddx( { module=>$module } );
    #ddx($_) for grep { -e "$_/$module" } map { "$prefix/$_" } @libs;
    $seen{$_}++ for grep { -e "$_/$module" } map { "$prefix/$_" } @libs;
    #ddx(\%seen);
  };
  #ddx(\%seen);
  @_ = map { path($_)->absolute->stringify } sort keys %seen;
  for(@_) {
    say "adding $_";
    unshift(@INC,$_);
  };
  return undef;
};
1;
