#!/usr/bin/perl

package AI::Util;
use AI::TextProc;
require Exporter;
our(@ISA)=qw(Exporter);
our(@EXPORT)=qw( pp format );

sub format;
*format=\&AI::TextProc::format;

sub pp {
  return "@_";
};



1;
