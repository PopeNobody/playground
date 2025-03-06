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
