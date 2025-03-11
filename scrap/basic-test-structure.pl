#!/usr/bin/perl
# Script to create a basic test suite structure

use strict;
use warnings;
use Path::Tiny;

# Create test directories
my @directories = (
    't',
    't/lib',
    't/data',
    't/fixtures'
);

foreach my $dir (@directories) {
    path($dir)->mkpath unless -d $dir;
    print "Created directory: $dir\n";
}

# Create basic test files
my %test_files = (
    't/00-load.t' => load_test(),
    't/01-textproc.t' => textproc_test(),
    't/02-msg.t' => msg_test(),
    't/03-conv.t' => conv_test(),
    't/data/sample_system_message.md' => sample_system_message(),
    't/fixtures/sample_conversation.jwrap' => sample_conversation()
);

foreach my $file (keys %test_files) {
    path($file)->spew($test_files{$file});
    print "Created test file: $file\n";
}

print "\nTest suite structure created successfully.\n";
print "Run tests with: prove -l t/\n";

# File content generators
sub load_test {
    return <<'EOF';
#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

#    # Test loading of main modules
use_ok('AI::TextProc') or BAIL_OUT("Failed to load AI::TextProc");
use_ok('AI::Msg') or BAIL_OUT("Failed to load AI::Msg");
use_ok('AI::Conv') or BAIL_OUT("Failed to load AI::Conv");

diag("Testing AI chat modules");

done_testing();
EOF
}

sub textproc_test {
    return <<'EOF';
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
EOF
}

sub msg_test {
    return <<'EOF';
#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Path::Tiny;
use AI::Msg;

# Test AI::Msg object creation and handling

# Test with basic parameters
my $msg1 = AI::Msg->new("user", "testuser", "Hello world");
isa_ok($msg1, 'AI::Msg', 'Object created with positional parameters');
is($msg1->{role}, 'user', 'Role set correctly');
is($msg1->{name}, 'testuser', 'Name set correctly');
is($msg1->{text}, 'Hello world', 'Text set correctly');

# Test with hash reference
my $msg2 = AI::Msg->new({
    role => 'assistant',
    name => 'ai',
    text => 'How can I help you?'
});
isa_ok($msg2, 'AI::Msg', 'Object created with hash reference');
is($msg2->{role}, 'assistant', 'Role set correctly from hash');
is($msg2->{name}, 'ai', 'Name set correctly from hash');
is($msg2->{text}, 'How can I help you?', 'Text set correctly from hash');

# Test with Path::Tiny for text
my $test_file = path("$Bin/data/sample_system_message.md");
my $msg3 = AI::Msg->new('system', 'system', $test_file);
isa_ok($msg3, 'AI::Msg', 'Object created with Path::Tiny for text');
like($msg3->{text}, qr/This is a sample system message/, 'Text loaded from file');

# Test serialization
my $jwrap = $msg1->as_jwrap();
is_deeply($jwrap, {
    role => 'user',
    name => 'testuser',
    text => ['Hello world']
}, 'as_jwrap() returns correct structure');

# Test deserialization
my $msg4 = AI::Msg->from_jwrap({
    role => 'system',
    name => 'system',
    text => ['Line 1', 'Line 2']
});
isa_ok($msg4, 'AI::Msg', 'Object created from jwrap');
is($msg4->{text}, "Line 1\nLine 2", 'Text joined correctly from array');

# Test with multi-line text
my $msg5 = AI::Msg->new("user", "testuser", "Line 1\nLine 2\nLine 3");
is($msg5->{text}, "Line 1\nLine 2\nLine 3", 'Multi-line text handled correctly');

# Test error conditions
eval { AI::Msg->new("user", "testuser", undef) };
like($@, qr/must not be null/, 'Error on undefined text');

eval { AI::Msg->new("user", "", "text") };
like($@, qr/must have length/, 'Error on empty name');

eval { AI::Msg->new({}) };
like($@, qr/missing in hash/, 'Error on empty hash');

done_testing();
EOF
}

sub conv_test {
    return <<'EOF';
#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Path::Tiny;
use AI::Conv;
use AI::Msg;

# Skip API tests if no API key
plan skip_all => "Set OPENAI_API_KEY to run all tests" 
    unless $ENV{OPENAI_API_KEY} || $ENV{API_KEY};

# Test conversation file handling
my $test_conv_file = path("$Bin/fixtures/test_conversation.jwrap");
$test_conv_file->remove if $test_conv_file->exists;

# Test creating a new conversation
my $conv = AI::Conv->new($test_conv_file);
isa_ok($conv, 'AI::Conv', 'Conversation object created');
is(scalar @{$conv->{msgs}}, 1, 'New conversation has 1 message (system)');
is($conv->{msgs}[0]{role}, 'system', 'First message is system message');

# Test adding a message
my $user_msg = AI::Msg->new('user', 'testuser', 'Test message');
$conv->add($user_msg);
is(scalar @{$conv->{msgs}}, 2, 'Message added to conversation');
is($conv->{msgs}[1]{text}, 'Test message', 'Message text correct');

# Test loading from file
my $conv2 = AI::Conv->new($test_conv_file);
is(scalar @{$conv2->{msgs}}, 2, 'Conversation loaded with correct message count');
is($conv2->{msgs}[1]{text}, 'Test message', 'Message content loaded correctly');

# Test API interaction (only if we have an API key)
SKIP: {
    skip "API tests require API_KEY environment variable", 2 
        unless $ENV{OPENAI_API_KEY} || $ENV{API_KEY};
    
    # Mock a simple response if needed
    local $AI::Conv::UA = Test::MockObject->new;
    $AI::Conv::UA->mock('request', sub {
        my $response = HTTP::Response->new(200);
        $response->content('{"choices":[{"message":{"content":"Test response"}}]}');
        return $response;
    });
    
    my $response = $conv->transact("Simple test question");
    is(scalar @{$conv->{msgs}}, 4, 'Conversation updated with request and response');
    is($response, 'Test response', 'Got correct API response');
}

# Test serialization to JSON
my $json = $conv->as_json();
like($json, qr/"role":"system"/, 'JSON contains system role');
like($json, qr/"role":"user"/, 'JSON contains user role');

# Cleanup
$test_conv_file->remove if $test_conv_file->exists;

done_testing();
EOF
}

sub sample_system_message {
    return <<'EOF';
# This is a sample system message

You are an AI assistant designed to help with various tasks.

## Capabilities
- Answer questions
- Generate code
- Have conversations
- Process data

Please provide helpful, accurate, and safe responses to user queries.
EOF
}

sub sample_conversation {
    return <<'EOF';
[
  {
    "role": "system",
    "name": "system",
    "text": [
      "# System Instructions",
      "",
      "You are an AI assistant designed for testing purposes.",
      "Please respond to all queries with test-appropriate responses."
    ]
  },
  {
    "role": "user",
    "name": "tester",
    "text": [
      "This is a test message."
    ]
  },
  {
    "role": "assistant",
    "name": "ai",
    "text": [
      "I acknowledge this is a test message. This is a test response."
    ]
  }
]
EOF
}
