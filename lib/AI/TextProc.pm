package AI::TextProc;
use FindBin;
our($prefix);
use Path::Tiny;
BEGIN {
  ($prefix)=path($FindBin::Bin);
  if($prefix->basename =~ m{s?bin} ){
    $prefix=$prefix->parent;
  };
};
BEGIN {
  use lib "$prefix/lib";
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
    next unless defined;
    if(blessed($_[$i]) and $_[$i]->isa("Path::Tiny")){
      splice(@_,$i,1,$_[$i]->slurp);
    } elsif (ref($_[$i]) eq 'ARRAY' ) {
      splice(@_,$i,1,@$_);
    } elsif (m{\n}) {
      splice(@_,$i,1,split(m{\n}));
    } else {
      $i++;
    };
  };
  if(wantarray){
    @_;
  } else {
    return join("\n",@_);
  };
};

1;
