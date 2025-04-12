package AI::TextProc;
use lib 'lib';
use AI::Config;
use AI::Util;
use Carp qw( confess carp croak cluck );
use Data::Dumper;
use FindBin;
use Path::Tiny;
use Scalar::Util qw(blessed);
use Text::Wrap qw(wrap $columns );
use common::sense;
$columns=80;
our($prefix,@keys);
sub format {
  local(@_)=@_;
  my $i=0;
  while($i<@_){
    local(*_)=\$_[$i];
    if(!defined) {
      splice(@_,$i,1);
    } elsif(blessed($_) and $_->isa("Path::Tiny")){
      splice(@_,$i,1,$_->slurp);
    } elsif (ref($_) eq 'ARRAY' ) {
      splice(@_,$i,1,@$_);
    } elsif (m{\n}) {
      splice(@_,$i,1,split(m{\n}));
    } else {
      $i++;
    };
  };
  local($_)=join("\n",@_);
  $_=wrap("","",$_);
  if(wantarray){
    return split(m{\n});
  } else {
    return $_;
  };
};

1;
