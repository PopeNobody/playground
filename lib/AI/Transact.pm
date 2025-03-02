package AI::Transact;

use strict;
use warnings;
use Exporter 'import';
use lib 'lib';
use Nobody::Util;
use LWP::UserAgent;
use JSON;
use Carp;

our @EXPORT_OK = ('transact');

# Stores AI configurations and UserAgent objects
our %AI;

sub transact {
    my ($ai_id, $conv, $message) = @_;
    
    croak "AI ID is required" unless $ai_id;
    croak "conv object required" unless $conv;
    croak "Message is required" unless defined $message;

    # Append user message to conv
    $conv->add( AI::Msg->new( "user", "rich", $message ));

    # Look up or initialize AI connection
    my $ai = $AI{$ai_id} //= {
        agent => LWP::UserAgent->new,
        creds => _load_ai_config($ai_id),
    };

    my $url = $ai->{creds}->{url} or croak "No API URL for AI ID: $ai_id";
    my $api_key = $ai->{creds}->{api_key} or croak "No API key for AI ID: $ai_id";

    # Prepare HTTP request
    my $req = HTTP::Request->new(POST => $url);
    $req->header('Content-Type' => 'application/json');
    $req->header('Authorization' => "Bearer $api_key");
    $req->content($conv->as_json());
    path("req.log")->spew($req->as_string);

    # Send request and process response
    my $res = $ai->{agent}->request($req);
    path("res.log")->spew($res->as_string);
    croak "Request failed: " . $res->status_line unless $res->is_success;

    my $response_data = decode_json($res->decoded_content);
    my $reply = $response_data->{choices}[0]{message}{content} // 'No response';

    # Append AI response to conv
    $conv->add(AI::Msg->new("assistant", $ai_id, $reply ));

    return $reply;
}

sub _load_ai_config {
    my ($ai_id) = @_;
    # Replace this with actual AI API keys and URLs
    my %config = (
        'gpt'  => { url => 'https://api.openai.com/v1/chat/completions', api_key => $ENV{OPENAI_API_KEY} },
        'gemini' => { url => 'https://gemini-ai.example/api', api_key => 'your-gemini-key' },
    );
    
    return $config{$ai_id} || croak "No configuration for AI ID: $ai_id";
}

1;
