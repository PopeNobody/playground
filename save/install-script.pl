root root 0755 bin/setup-services 65
#!/bin/bash
# Setup daemontools services for AI executor daemons
# Usage: setup-services [--remove]

# Configuration
PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SERVICE_DIR="/service"
PROVIDERS=("gpt" "claude" "gemini" "grok")

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root to set up system services"
  echo "Try: sudo $0"
  exit 1
fi

# Remove services
if [ "$1" == "--remove" ]; then
  echo "Removing AI executor services..."
  for provider in "${PROVIDERS[@]}"; do
    SERVICE_PATH="$SERVICE_DIR/ai-$provider"
    if [ -L "$SERVICE_PATH" ]; then
      echo "  Removing service: ai-$provider"
      rm -f "$SERVICE_PATH"
    fi
  done
  echo "Services removed."
  exit 0
fi

# Create service directories and symlinks
echo "Setting up AI executor services..."

# Ensure run script is executable
chmod +x "$PROJECT_DIR/bin/service-run"

for provider in "${PROVIDERS[@]}"; do
  SERVICE_PATH="$SERVICE_DIR/ai-$provider"
  
  # Check if service already exists
  if [ -e "$SERVICE_PATH" ]; then
    echo "  Service ai-$provider already exists, skipping"
    continue
  fi
  
  # Create service directories
  mkdir -p "$PROJECT_DIR/service/ai-$provider/log"
  
  # Create run script symlink
  ln -sf "$PROJECT_DIR/bin/service-run" "$PROJECT_DIR/service/ai-$provider/run"
  chmod +x "$PROJECT_DIR/service/ai-$provider/run"
  
  # Create log service
  cat > "$PROJECT_DIR/service/ai-$provider/log/run" << EOF
#!/bin/sh
exec multilog t s1048576 n10 "$PROJECT_DIR/logs/ai-$provider"
EOF
  chmod +x "$PROJECT_DIR/service/ai-$provider/log/run"
  
  # Create service symlink
  ln -sf "$PROJECT_DIR/service/ai-$provider" "$SERVICE_DIR/ai-$provider"
  
  echo "  Service created: ai-$provider"
done

echo "Services setup complete. To start them, use: svc -u /service/ai-*"
echo "To check status: svstat /service/ai-*"
.
root root 0644 etc/environment.sh.template 25
#!/bin/bash
# Environment configuration for AI services
# Copy this file to environment.sh and customize

# API Keys
export API_KEY="your-openai-api-key-here"
export ANTHROPIC_API_KEY="your-anthropic-api-key-here"
export GOOGLE_API_KEY="your-google-api-key-here"
export XAI_API_KEY="your-xai-api-key-here"

# Default model
export API_MODEL="gpt-4o"

# Socket paths
export SOCKET_DIR="$PROJECT_DIR/ai_sockets"
export GPT_SOCKET="$SOCKET_DIR/gpt.sock"
export CLAUDE_SOCKET="$SOCKET_DIR/claude.sock"
export GEMINI_SOCKET="$SOCKET_DIR/gemini.sock"
export GROK_SOCKET="$SOCKET_DIR/grok.sock"

# Log configuration
export LOG_DIR="$PROJECT_DIR/ai_logs"
export DEBUG=0
.
root root 0644 lib/AI/Client.pm 367
package AI::Client;

use strict;
use warnings;
use common::sense;
use Exporter 'import';
use Path::Tiny;
use JSON;
use LWP::UserAgent;
use HTTP::Request;
use Nobody::Util;
use AI::Msg;
use Carp qw(croak);
use IO::Socket::UNIX;
use User::pwent;

our @EXPORT_OK = qw(create_client);

# Client configuration
my $DEFAULT_TIMEOUT = 90;

# Create a new API client
sub create_client {
    my ($args) = @_;
    
    # Copy args to prevent modifying the original
    my %config = %{$args || {}};
    
    # Required parameters
    my $model = $config{model} || $ENV{API_MODEL} || croak "Model is required";
    
    # Try to get API key from various environment variables based on model
    my $api_key = $config{api_key};
    if (!$api_key) {
        if ($model =~ /^claude/i || $model =~ /^anthropic/i) {
            $api_key = $ENV{ANTHROPIC_API_KEY} || $ENV{API_KEY};
        } elsif ($model =~ /^gemini/i || $model =~ /^google/i) {
            $api_key = $ENV{GOOGLE_API_KEY} || $ENV{API_KEY};
        } elsif ($model =~ /^grok/i || $model =~ /^x/i) {
            $api_key = $ENV{XAI_API_KEY} || $ENV{API_KEY};
        } else {
            # Default to OpenAI
            $api_key = $ENV{OPENAI_API_KEY} || $ENV{API_KEY};
        }
    }
    
    croak "API key not found for model: $model" unless $api_key;
    
    # Map shorthand names to actual models and providers
    my %provider_map = (
        'gpt' => { provider => 'gpt', model => $ENV{GPT_MODEL} || 'gpt-4o' },
        'claude' => { provider => 'claude', model => $ENV{CLAUDE_MODEL} || 'claude-3-5-sonnet' },
        'gem' => { provider => 'gemini', model => $ENV{GEMINI_MODEL} || 'gemini-1.5-flash' },
        'grok' => { provider => 'grok', model => $ENV{GROK_MODEL} || 'grok-2-latest' },
    );
    
    # Check if this is a shorthand name
    my $provider = 'default';
    my $original_model = $model;
    
    if ($provider_map{lc($model)}) {
        $provider = $provider_map{lc($model)}->{provider};
        $model = $provider_map{lc($model)}->{model};
    }
    # Extract provider from full model name if not a shorthand
    elsif ($model =~ /^claude/i) {
        $provider = 'claude';
    } elsif ($model =~ /^gemini/i) {
        $provider = 'gemini';
    } elsif ($model =~ /^grok/i) {
        $provider = 'grok';
    } elsif ($model =~ /^gpt/i) {
        $provider = 'gpt';
    }
    
    # Create client object with provider information
    my $client = {
        model => $model,
        provider => $provider,
        original_model => $original_model,
        timeout => $config{timeout} || $DEFAULT_TIMEOUT,
        user_agent => _create_user_agent($config{timeout} || $DEFAULT_TIMEOUT),
        debug => $config{debug} || 0,
        conversation => $config{conversation} || [],
    };
    
    return bless $client, __PACKAGE__;
}

# Load model configuration from JSON files
sub _load_model_config {
    my ($model) = @_;
    
    # Try to find a specific model config file
    my @config_paths = (
        "etc/$model.json",
        "etc/models/$model.json"
    );
    
    # Look for model handle (short name) in config files
    my @model_files = glob("etc/*.json");
    
    foreach my $file (@config_paths, @model_files) {
        my $path = path($file);
        next unless $path->exists;
        
        my $json = $path->slurp;
        my $config = eval { decode_json($json) };
        if ($@) {
            warn "Error parsing $file: $@";
            next;
        }
        
        # Check if this is the right model or handle
        if ($config->{model} eq $model || $config->{handle} eq $model) {
            return $config;
        }
    }
    
    # If no specific model file found, try loading default config
    my $default_path = path("etc/model.json");
    if ($default_path->exists) {
        my $json = $default_path->slurp;
        my $config = decode_json($json);
        return $config;
    }
    
    croak "Could not find configuration for model: $model";
}

# Create LWP user agent
sub _create_user_agent {
    my ($timeout) = @_;
    
    my $ua = LWP::UserAgent->new(
        timeout => $timeout,
        ssl_opts => { verify_hostname => 1 },
    );
    
    $ua->agent("AI-Playground-Client/0.1");
    
    return $ua;
}

# Send a message to the API
sub send_message {
    my ($self, $args) = @_;
    
    # Copy args to prevent modifying the original
    my %params = %{$args || {}};
    
    # Required parameters
    my $message = $params{message} || croak "Message is required";
    
    # Optional parameters
    my $system_message = $params{system_message};
    my $temperature = $params{temperature} || 0.7;
    my $max_tokens = $params{max_tokens} || 4096;
    
    # Determine server URL based on provider
    my $server_url = $params{server_url};
    
    if (!$server_url) {
        # Get user ID for the provider
        my $uid = getpwnam($self->{provider});
        if ($uid) {
            $server_url = "http://localhost:$uid/ai_api";
        } else {
            # Fall back to environment variable or default
            $server_url = $ENV{$self->{provider} . "_SERVER_URL"} || 
                          $ENV{AI_SERVER_URL} || 
                          "http://localhost:4001/ai_api";
        }
    }
    
    # Build conversation history
    my @messages;
    
    # Add system message if provided
    if ($system_message) {
        push @messages, {
            role => "system",
            content => $system_message
        };
    }
    
    # Add conversation history
    if ($params{conversation}) {
        foreach my $msg (@{$params{conversation}}) {
            push @messages, {
                role => $msg->{role},
                content => $msg->{content}
            };
        }
    } elsif ($self->{conversation}) {
        foreach my $msg (@{$self->{conversation}}) {
            push @messages, {
                role => $msg->{role},
                content => $msg->{content}
            };
        }
    }
    
    # Add the current message
    push @messages, {
        role => "user",
        content => $message
    };
    
    # Prepare the request for the server
    my $request_data = {
        model => $self->{model},
        messages => \@messages,
        temperature => $temperature,
        max_tokens => $max_tokens,
        execute_scripts => $params{execute_scripts} // 1,
    };
    
    # Add any additional parameters
    foreach my $key (keys %params) {
        next if $key =~ /^(message|system_message|temperature|max_tokens|conversation|server_url)$/;
        $request_data->{$key} = $params{$key};
    }
    
    my $json = encode_json($request_data);
    
    # Create HTTP request to the server
    my $req = HTTP::Request->new(POST => $server_url);
    $req->header('Content-Type' => 'application/json');
    
    # No need for API key - server handles authentication
    $req->content($json);
    
    # Debug logging
    if ($self->{debug}) {
        print STDERR "Request to server: " . $req->as_string . "\n";
    }
    
    # Send the request
    my $res = $self->{user_agent}->request($req);
    
    # Debug logging
    if ($self->{debug}) {
        print STDERR "Response from server: " . $res->as_string . "\n";
    }
    
    # Handle errors
    unless ($res->is_success) {
        my $error = "Server request failed: " . $res->status_line;
        if ($self->{debug}) {
            $error .= "\n\nResponse: " . $res->decoded_content;
        }
        croak $error;
    }
    
    # Parse response
    my $response_data = decode_json($res->decoded_content);
    
    # Extract content from server response
    my $content;
    
    if (exists $response_data->{response}) {
        # Server's own format
        $content = $response_data->{response};
    } elsif (exists $response_data->{choices}[0]{message}{content}) {
        # Raw OpenAI format
        $content = $response_data->{choices}[0]{message}{content};
    } else {
        # Unknown format, return the whole response
        $content = "Unrecognized response format: " . encode_json($response_data);
    }
    
    # Process script execution results if present
    if (exists $response_data->{script_results}) {
        $self->{last_execution_results} = $response_data->{script_results};
        
        # Append execution results to the content if requested
        if ($params{append_results} // 1) {
            $content .= "\n\n--- Script Execution Results ---\n";
            foreach my $result (@{$response_data->{script_results}}) {
                $content .= "Exit code: " . $result->{exit_code} . "\n";
                $content .= "Output:\n" . $result->{output} . "\n";
                if ($result->{error}) {
                    $content .= "Errors:\n" . $result->{error} . "\n";
                }
                $content .= "---------------------------\n";
            }
        }
    }
    
    # Update conversation history
    if ($params{update_conversation} // 1) {
        push @{$self->{conversation}}, {
            role => "user",
            content => $message
        };
        
        push @{$self->{conversation}}, {
            role => "assistant",
            content => $content
        };
    }
    
    return $content;
}

# Save conversation to file
sub save_conversation {
    my ($self, $args) = @_;
    
    my $file = $args->{file} || croak "File path is required";
    $file = path($file);
    
    # Create parent directories if they don't exist
    $file->parent->mkpath;
    
    # Write JSON
    $file->spew(encode_json($self->{conversation}));
    
    return $self;
}

# Load conversation from file
sub load_conversation {
    my ($self, $args) = @_;
    
    my $file = $args->{file} || croak "File path is required";
    $file = path($file);
    
    croak "File does not exist: $file" unless $file->exists;
    
    my $json = $file->slurp;
    my $conversation = decode_json($json);
    
    $self->{conversation} = $conversation;
    
    return $self;
}

1;
