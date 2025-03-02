package AI::Connect::Claude;

use strict;
use warnings;
use lib 'lib';
use LWP::UserAgent;
use JSON;
use HTTP::Request;
use Nobody::Util;
use Data::Dumper;

# Create and export the adapter function
sub translate_request {
    my ($conv_data, $api_key, $model) = @_;
    
    # Default model if not specified
    $model ||= $ENV{API_MOD} || 'claude-3-5-sonnet-20240620';
    
    # Extract messages from the conversation data
    my $messages = [];
    foreach my $msg (@$conv_data) {
        my $role = $msg->{role};
        
        # Map OpenAI roles to Anthropic roles
        if ($role eq 'assistant') {
            $role = 'assistant';
        } elsif ($role eq 'system') {
            $role = 'system';
        } else {
            $role = 'user';
        }
        
        push @$messages, {
            role => $role,
            content => $msg->{content}
        };
    }
    
    # Construct the Claude API request
    my $request = {
        model => $model,
        messages => $messages,
        max_tokens => 4096,
        temperature => 0.7
    };
    
    return encode_json($request);
}

# Rest of the module...
