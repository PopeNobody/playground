package AI::TextProc;
use FindBin;
our($prefix);
use Path::Tiny;
BEGIN {
  use lib "$ENV{PWD}";
};
use common::sense;
use Nobody::Util;
use Path::Tiny;
use Data::Dumper;
use Carp qw( confess carp croak cluck );
use common::sense;
use Scalar::Util qw(blessed);
use Text::Wrap qw(wrap $columns );
$columns=30;
our(@keys);
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
