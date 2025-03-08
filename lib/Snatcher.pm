package Snatcher;
use common::sense;
use Nobody::Util;
use lib "$ENV{PWD}";

END {
  my @inc=map { "$_/" } sort @INC;
  my @val=map { "$_" } sort grep { m{^/} } values %INC;
  path("output")->spew(pp([@_]));
}
1;
