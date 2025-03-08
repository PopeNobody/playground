#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Path::Tiny;
use AI::TextProc;

# Test text processing with various input types

# Test with plain string
my $plain_text = "This is a test";
my $result = AI::TextProc::format($plain_text);
is($result, "This is a test", "Format plain text");

# Test with multi-line string
my $multiline = "Line 1\nLine 2\nLine 3";
my @lines = AI::TextProc::format($multiline);
is_deeply(\@lines, ["Line 1", "Line 2", "Line 3"], "Format multiline string into array");
is(AI::TextProc::format($multiline), "Line 1\nLine 2\nLine 3", "Format multiline string");

# Test with array of strings
my @array = ("Item 1", "Item 2", "Item 3");
$result = AI::TextProc::format(@array);
is($result, "Item 1\nItem 2\nItem 3", "Format array of strings");

# Test with array ref
my $array_ref = ["Array 1", "Array 2", "Array 3"];
$result = AI::TextProc::format($array_ref);
is($result, "Array 1\nArray 2\nArray 3", "Format array reference");

# Test with Path::Tiny object
my $test_file = path("$Bin/data/sample_system_message.md");
$result = AI::TextProc::format($test_file);
$result =~ s{\n}{ }g;
like($result, qr/This is a sample system message/, "Format Path::Tiny object");

# Test with mixed input
$result = AI::TextProc::format("First line", ["Second line", "Third line"], "Fourth line");
is($result, "First line\nSecond line\nThird line\nFourth line", "Format mixed input");

# Test with undefined values
$result = AI::TextProc::format("Valid", undef, "Also valid");
is($result, "Valid\nAlso valid", "Format with undefined values");

# Test empty strings
$result = AI::TextProc::format("Start", "", "End");
is($result, "Start\n\nEnd", "Format with empty strings");

done_testing();
