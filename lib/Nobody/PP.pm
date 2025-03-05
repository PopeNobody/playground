package Nobody::PP;

use common::sense;
use vars qw(@EXPORT @EXPORT_OK $VERSION $DEBUG %EXPORT_TAGS @subs);
use subs qq(pp dd ppx ddx quote); 

require Exporter;
*import = \&Exporter::import;
@EXPORT_OK = qw(pp dd ppx ddx ee eex quote qquote loc);
@EXPORT = @subs;
%EXPORT_TAGS = ( 
  all=>[ @EXPORT_OK ],
);

sub pp
{
  use Data::Dumper;
  local($Data::Dumper::Terse)=1;
  local($Data::Dumper::Deparse)=1;
  local($Data::Dumper::Useqq)=1;
  local($Data::Dumper::Sortkeys)=1;
  Dumper( @_ );
}
sub ee {
    print STDERR pp(@_), "\n";
}
sub dd {
    print pp(@_), "\n";
}

sub loc {
  my($idx)=0;
  my($pkg, $file, $line);
  do {
    ($pkg,$file,$line)=caller($idx++);
  } while($pkg eq 'Nobody::PP');
  join(':',$file,$line,"@_");
};
sub ppx {
  return loc(pp(@_));
}
sub ddx {
  say STDOUT ppx(@_);
}
sub eex {
  say STDERR ppx(@_);
};
