#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use_ok('AI::TextProc') or BAIL_OUT("Failed to load AI::TextProc");
use_ok('AI::Msg') or BAIL_OUT("Failed to load AI::Msg");
use_ok('AI::Conv') or BAIL_OUT("Failed to load AI::Conv");
use_ok('MIME::Types') or BAIL_OUT("Failed to load Mime::Types");

diag("Testing AI chat modules");

done_testing();
