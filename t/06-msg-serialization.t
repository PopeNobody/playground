#!/usr/bin/perl
# test-msg-serialization.pl - Test AI::Msg serialization/deserialization
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Path::Tiny;
use AI::Msg;
use AI::Util;
use Test::More;

# Create test directory if it doesn't exist
my $test_dir = path("$Bin/test_data");
$test_dir->mkpath unless $test_dir->exists;

# Test 1: Create a message and serialize to jwrap
print "Test 1: Create message and serialize to jwrap\n";
my $msg1 = AI::Msg->new({
    role => 'user',
    name => 'testuser',
    text => "This is a test message.\nWith multiple lines.\nTo test serialization."
});

ok($msg1->as_json, "Created AI::Msg object");
is($msg1->{role}, 'user', "Role is set correctly");
is($msg1->{name}, 'testuser', "Name is set correctly");
like($msg1->{text}, qr/multiple lines/, "Text contains expected content");

# Serialize to jwrap format
my $jwrap = $msg1->as_jwrap();
ok($jwrap, "Generated jwrap data");
is(ref($jwrap), 'HASH', "Jwrap is a hash reference");
is(ref($jwrap->{text}), 'ARRAY', "Text is converted to array in jwrap");
is(scalar @{$jwrap->{text}}, 3, "Text array has correct number of lines");

# Save jwrap to file
my $jwrap_file = $test_dir->child("test_msg.jwrap");
$jwrap_file->spew(encode_json($jwrap));
ok(-e $jwrap_file, "Jwrap file was created");

# Test 2: Deserialize from jwrap
print "\nTest 2: Deserialize from jwrap\n";
my $json_data = decode_json($jwrap_file->slurp);
my $msg2 = AI::Msg->from_jwrap($json_data);

ok(defined $msg2, "Created AI::Msg from jwrap");
is($msg2->{role}, $msg1->{role}, "Role matches original");
is($msg2->{name}, $msg1->{name}, "Name matches original");
is($msg2->{text}, $msg1->{text}, "Text matches original");

# Test 3: Round-trip conversion
print "\nTest 3: Round-trip conversion\n";
my $jwrap2 = $msg2->as_jwrap();
is_deeply($jwrap2, $jwrap, "Round-trip conversion preserves data");

# Test 4: Create message directly with multi-line string and positional params
print "\nTest 4: Create with positional params\n";
my $msg3 = AI::Msg->new('assistant', 'ai', "Response line 1\nResponse line 2");
ok(defined $msg3, "Created AI::Msg with positional parameters");
is($msg3->{role}, 'assistant', "Role is set correctly");
is($msg3->{name}, 'ai', "Name is set correctly");
is($msg3->{text}, "Response line 1\nResponse line 2", "Text is set correctly");

# Test 5: Create with Path::Tiny for text
print "\nTest 5: Create with Path::Tiny\n";
my $text_file = $test_dir->child("test_text.txt");
$text_file->spew("Line 1 from file\nLine 2 from file\nLine 3 from file");

my $msg4 = AI::Msg->new('system', 'system', $text_file);
ok(defined $msg4, "Created AI::Msg with Path::Tiny for text");
is($msg4->{role}, 'system', "Role is set correctly");
is($msg4->{name}, 'system', "Name is set correctly");
like($msg4->{text}, qr/Line 1 from file/, "Text contains expected content");
like($msg4->{text}, qr/Line 3 from file/, "Text contains later lines");

# Test 6: Auto-detect MIME type for scripts with shebang lines
print "\nTest 6: Auto-detect MIME type for scripts\n";
my $bash_script = <<'EOT';
#!/bin/bash
# Test bash script
echo "Hello from Bash!"
ls -la
EOT

my $python_script = <<'EOT';
#!/usr/bin/env python3
# Test Python script
import sys
print("Hello from Python!")
print(f"Python version: {sys.version}")
EOT

my $perl_script = <<'EOT';
#!/usr/bin/perl
# Test Perl script
use strict;
use warnings;
print "Hello from Perl!\n";
print "Perl version: $^V\n";
EOT

# Test with bash script
my $bash_msg = AI::Msg->new('user', 'testuser', $bash_script);
ok(defined $bash_msg, "Created AI::Msg with bash script");
is($bash_msg->{type}, 'application/x-sh', 
  "Type correctly set to executable for bash script");

# Test with python script
my $python_msg = AI::Msg->new('user', 'testuser', $python_script);
ok(defined $python_msg, "Created AI::Msg with python script");
is($python_msg->{type}, 'application/x-py', 
  "Type correctly set to executable for python script");

# Test with perl script
my $perl_msg = AI::Msg->new('user', 'testuser', $perl_script);
ok(defined $perl_msg, "Created AI::Msg with perl script");
is($perl_msg->{type}, 'application/x-pl', 
  "Type correctly set to executable for perl script");

# Test round-trip preservation of type
my $jwrap_bash = $bash_msg->as_jwrap();
my $restored_bash_msg = AI::Msg->from_jwrap($jwrap_bash);
is($restored_bash_msg->{type}, 'application/x-sh', 
  "Type preserved in jwrap round-trip");

# Clean up test files
$jwrap_file->remove;
$text_file->remove;

done_testing();
print "\nAll tests completed successfully!\n";
