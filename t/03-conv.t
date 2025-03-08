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
use Test::MockObject;
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
