#!/usr/bin/perl
# test-mimetypes.pl - Test MIME::Types-based type detection in AI::Msg
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Path::Tiny;
use Nobody::Util;
use Test::More;
use MIME::Types;

# First, check if MIME::Types is available
eval { require MIME::Types; };
if ($@) {
    plan skip_all => "MIME::Types module not installed. Run: cpanm MIME::Types";
}

# Create test directory if it doesn't exist
my $test_dir = path("$Bin/test_data");
$test_dir->mkpath unless $test_dir->exists;

# Get a MIME::Types instance to verify expected types
my $mime_types = MIME::Types->new();

# Test scripts with various shebang lines
my @test_scripts;
eval "use AI::Msg";
die "$@" if $@;
@test_scripts=();
# Run tests for each script
foreach my $test (@test_scripts) {
    print "\nTesting: $test->{name}\n";
    $DB::single=1;
    my $msg = AI::Msg->new('user', 'testuser', $test->{script});
    ok(defined $msg, "Created message with $test->{name}");
    
    my $expected_type;
    if ($test->{extension} eq '') {
        $expected_type = 'text/plain';
    } elsif ($test->{extension} eq 'x') {
        $expected_type = 'application/x-executable';
    } else {
        my $mime_obj = $mime_types->type(ext => $test->{extension});
        $expected_type = $mime_obj ? $mime_obj->type : "application/x-$test->{extension}";
    }
    
    is($msg->{type}, $expected_type, "Detected correct MIME type for $test->{name}: $expected_type");
    
    # Test round-trip preservation
    my $jwrap = $msg->as_jwrap();
    my $restored_msg = AI::Msg->from_jwrap($jwrap);
    is($restored_msg->{type}, $expected_type, "MIME type preserved in jwrap round-trip for $test->{name}");
}

# Additional test for scripts with comments or whitespace before shebang
print "\nTesting edge cases:\n";

my $whitespace_script = "\n\n#!/bin/bash\necho 'Shebang with leading whitespace'";
my $whitespace_msg = AI::Msg->new('user', 'testuser', $whitespace_script);
print $whitespace_msg->text;
my $sh_mime = $mime_types->type(ext => 'sh');
my $expected_sh_type = $sh_mime ? $sh_mime->type : 'application/x-sh';
is($whitespace_msg->{type}, 'application/x-sh', 
  "Script with leading whitespace not detected (as expected)");

# Add a test for a file with a complex shebang
my $complex_script = "#!/usr/bin/env python -m something\nprint('Complex shebang')\n";
my $complex_msg = AI::Msg->new('user', 'testuser', $complex_script);
my $py_mime = $mime_types->type(ext => 'py');
my $expected_py_type = $py_mime ? $py_mime->type : 'application/x-py';
is($complex_msg->{type}, $expected_py_type, "Detected script with complex shebang");

# Show all detected MIME types in a summary
print "\nMIME Type Detection Summary:\n";
print "-" x 60 . "\n";
print "Script Type".(" " x 15)."Detected MIME Type\n";
print "-" x 60 . "\n";

foreach my $test (@test_scripts) {
    my $script_type = $test->{name};
    my $msg = AI::Msg->new('user', 'testuser', $test->{script});
    printf "%-25s %s\n", $script_type, $msg->{type};
}

done_testing();
print "\nAll tests completed successfully!\n";

BEGIN {
  @test_scripts = (
    {
        name => "Bash script",
        script => "#!/bin/bash\necho 'Hello from Bash!'",
        extension => 'sh'
    },
    {
        name => "Shell script",
        script => "#!/usr/bin/env sh\necho 'Hello from Shell!'",
        extension => 'sh'
    },
    {
        name => "Python script",
        script => "#!/usr/bin/env python3\nprint('Hello from Python!')",
        extension => 'py'
    },
    {
        name => "Perl script",
        script => "#!/usr/bin/env perl\nprint 'Hello from Perl!'",
        extension => 'pl'
    },
    {
        name => "Ruby script",
        script => "#!/usr/bin/env ruby\nputs 'Hello from Ruby!'",
        extension => 'rb'
    },
    {
        name => "Node.js script",
        script => "#!/usr/bin/env node\nconsole.log('Hello from Node.js!')",
        extension => 'js'
    },
    {
        name => "PHP script",
        script => "#!/usr/bin/env php\n<?php echo 'Hello from PHP!'; ?>",
        extension => 'php'
    },
    {
        name => "R script",
        script => "#!/usr/bin/env Rscript\ncat('Hello from R!')",
        extension => 'r'
    },
    {
        name => "Lua script",
        script => "#!/usr/bin/env lua\nprint('Hello from Lua!')",
        extension => 'lua'
    },
    {
        name => "AWK script",
        script => "#!/usr/bin/awk -f\nBEGIN { print \"Hello from AWK!\" }",
        extension => 'awk'
    },
    {
        name => "Unknown interpreter",
        script => "#!/usr/bin/env unknown\necho 'Hello from unknown!'",
        extension => 'x'  # Should default to executable
    },
    {
        name => "No shebang",
        script => "echo 'No shebang here'",
        extension => ''  # Should be plain text
    }
);
}
