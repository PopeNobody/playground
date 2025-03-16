#!/usr/bin/perl
use strict;
use warnings;
BEGIN {
  delete $ENV{API_MOD};
  delete $ENV{API_KEY};
  $ENV{API_LOCAL}=1;
  $ENV{API_QUIET}=1;
};
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Path::Tiny;
use AI::Util;
use AI::Conv;
use AI::Msg;

# Test conversation file handling
my $test_conv_dir = path("$Bin/fixtures/test_conversation");
system("rm -fr $test_conv_dir") if $test_conv_dir->exists;

# Test creating a new conversation
my $conv = AI::Conv->new($test_conv_dir);
isa_ok($conv, 'AI::Conv', 'Conversation object created');
is(scalar @{$conv->{msgs}}, 1, 'New conversation has 1 message (system)');
is($conv->{msgs}[0]{role}, 'system', 'First message is system message');

# Test adding a message
my $user_msg = AI::Msg->new('user', 'testuser', 'Test message');
$conv->add($user_msg);
is(scalar @{$conv->{msgs}}, 2, 'Message added to conversation');
is($conv->{msgs}[1]{text}, 'Test message', 'Message text correct');

# Test loading from file
my $conv2 = AI::Conv->new($test_conv_dir);
is(scalar @{$conv2->{msgs}}, 2, 'Conversation loaded with correct message count');
is($conv2->{msgs}[1]{text}, 'Test message', 'Message content loaded correctly');
use Test::MockObject;
# Test API interaction (only if we have an API key)
SKIP: {
    # Mock a simple response if needed
    local $AI::Config::config{ua} = Test::MockObject->new;
    $AI::Config::config{ua}->mock('request', sub {
      my $response = HTTP::Response->new(200);
      $response->content('{"choices":[{"message":{"content":"Test response"}}]}');
      return $response;
    });
    $AI::Config::config{model}="MockModel";
    $AI::Config::config{ua}->mock('cookie_jar', sub {
        return undef;
    });
    my $msg = AI::Msg->new("user","nobody", q{
      Plase answer with exactly 'Test response'
      });
    $conv->add($msg);    
    my $response = $conv->transact();
    is(scalar @{$conv->{msgs}}, 4, 'Conversation updated with request and response');
    my $res = decode_json($response->as_json());
    is($res->{content}, 'Test response', 'Got correct API response');
}

# Test serialization to JSON
my $json = $conv->as_json();
#    like($json, qr/"role":"system"/, 'JSON contains system role');
#    like($json, qr/"role":"user"/, 'JSON contains user role');

# Cleanup
system("rm -fr $test_conv_dir") if $test_conv_dir->exists;

done_testing();
