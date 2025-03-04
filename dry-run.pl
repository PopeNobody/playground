#!/usr/bin/perl
# vim: ts=2 sw=2 ft=perl
eval 'exec perl -x -wS $0 ${1+"$@"}'
  if 0;
$|++;
use common::sense;
#use autodie;
use Nobody::Util;
use Snatcher;
our(@VERSION) = qw( 0 1 0 );
use AI::Conv;
use AI::Transact qw(transact);
my ($base) = map { path($_) } grep { s{[.]pl$}{} } $Script;
my ($data) = eval path("$base-text.pl")->slurp;
my ($conv) = AI::Conv->new(path("$base.jwrap"));
my ($idx) = shift @$data;
ddx($data);
my ($msg) = AI::Msg->new("role","name","text");
ddx( $msg );
my $i;
for($i=1000;$i<9999;++$i)
{
  next if -e "$base.$i.jwrap";
  system("cp", "$base.jwrap", "$base.$i.jwrap");
  last;
};
for($data->[$idx]) {
  ddx($idx,$_);
  $conv->add(AI::Msg->new($_->{role},$_->{name},$_->{text}));
  $conv=$conv->new($conv->file);
  ddx($conv);
};
unshift(@$data,++$idx);
use Data::Dumper;
$Data::Dumper::Terse=1;
spit("$base-test.pl",Dumper(@$data));
