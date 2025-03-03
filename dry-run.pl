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
my (%obj);
ddx($data);
print "\n\n\n";
my ($msg) = AI::Msg->new("role","name","text");
ddx( $msg );
$conv->add($msg);
exit(0);
for($data->[$idx]) {
  *obj=$_;
  $conv->add(AI::Msg->new($obj{role},$obj{name},$obj{text}));
  my $i;
  for($i=1000;$i<9999;++$i)
  {
    next if -e "$base.$i.jwrap";
    last;
  };
  system("cp", "$base.jwrap", "$base.$i.jwrap");
  $conv=$conv->new($conv->file);
  ddx($conv);
};
unshift(@$data,++$idx);
use Data::Dumper;
$Data::Dumper::Terse=1;
spit("$base-test.pl",Dumper(@$data));
