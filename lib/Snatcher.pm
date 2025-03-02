package Snatcher;
use common::sense;
use Nobody::Util;
# Hook require to auto-copy missing modules into ./lib

our (%BlackLis,  @inc, $cwd);
END {
  my @inc=map { "$_/" } sort @INC;
  my @val=map { "$_" } sort grep { m{^/} } values %INC;
  path("output")->spew(pp([@_]));
}
1;
