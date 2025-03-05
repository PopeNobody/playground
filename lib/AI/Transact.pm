package AI::Transact;

use strict;
use warnings;
use Exporter 'import';
use lib 'lib';
use Nobody::Util;
use LWP::UserAgent;
use JSON::Pretty;
use Carp;
use AI::Msg;
use AI::Config qw(get_api_info get_api_key);

our @EXPORT_OK = ('transact');

# Persistent user agent and API info
our $UA;
our $API_URL;
our $MODEL;

# Initialize globals at module load time
BEGIN {
  my $api_info = get_api_info();
  my $api_key = get_api_key();
  croak "missing API key" unless defined $api_key;
  if ($api_key) {
    $UA = LWP::UserAgent->new;
    $API_URL = $api_info->{url}->{api};
    $MODEL = $api_info->{model};

    # Add default header for authentication
    $UA->default_header('Authorization' => "Bearer $api_key");
  }
}

sub transact {
    my ($conv, $message) = @_;
    
    croak "conv object required" unless $conv;
    croak "API not initialized - missing API key?" unless $UA;

    # Append user message to conv
    # If the user message is the empty string, then he just wants
    # the response of the ai to the conversation as it stands ...
    # but we make him do this explicitly by sending an empty string.
    croak "Message is required" unless defined $message;
    $conv->add(AI::Msg->new("user", "user", $message)) if length $message;
    
    # Prepare HTTP request
    my $req = HTTP::Request->new(POST => "$API_URL/chat/completions");
    $req->header('Content-Type' => 'application/json');
    
    # Prepare payload with OpenAI format
    my $payload = {
        model => $MODEL,
        messages => [],
        temperature => 0.7,
        max_tokens => 4096
    };
    
    # Extract messages from conversation (without 'name' field)
    foreach my $msg (@{$conv->{msgs}}) {
        push @{$payload->{messages}}, {
            role => $msg->{role},
            content => $msg->{text}
        };
    }
    
    $req->content(encode_json($payload));
    
    # Store redacted request for debugging
    my $redacted_req = $req->clone;
    $redacted_req->header('Authorization', 'Bearer [REDACTED]');
    path("req.log")->spew($redacted_req->as_string);
    
    # Send request
    my $res = $UA->request($req);
    
    # Store response for debugging
    path("res.log")->spew($res->as_string);
    
    # Handle errors
    unless ($res->is_success) {
        my $error = "API request failed: " . $res->status_line . "\n\n";
        $error .= "Request: " . $redacted_req->as_string . "\n\n";
        $error .= "Response: " . $res->as_string;
        croak $error;
    }

    # Parse response
    my $response_data = decode_json($res->decoded_content);
    my $reply = $response_data->{choices}[0]{message}{content};
    
    # Handle missing content
    unless (defined $reply) {
        $reply = "No response content received from API. Full response: " . encode_json($response_data);
    }

    # Append AI response to conv
    $conv->add(AI::Msg->new("assistant", "ai", $reply));

    return $reply;
}
sub model_list {

}
1;
