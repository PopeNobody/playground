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
    
    # Create client object (simplified for server proxy approach)
    my $client = {
        model => $model,
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
    
    # Prepare the request
    my $request_data = {
        model => $self->{model},
        messages => \@messages,
        temperature => $temperature,
        max_tokens => $max_tokens,
    };
    
    # Add any additional parameters
    foreach my $key (keys %params) {
        next if $key =~ /^(message|system_message|temperature|max_tokens|conversation)$/;
        $request_data->{$key} = $params{$key};
    }
    
    my $json = encode_json($request_data);
    
    # Create HTTP request
    my $req = HTTP::Request->new(POST => "$self->{base_url}/chat/completions");
    $req->header('Content-Type' => 'application/json');
    
    # Add authentication
    if ($self->{auth_type} eq 'bearer') {
        $req->header('Authorization' => "Bearer $self->{api_key}");
    } elsif ($self->{auth_type} eq 'api-key') {
        $req->header('x-api-key' => $self->{api_key});
    }
    
    $req->content($json);
    
    # Debug logging
    if ($self->{debug}) {
        my $debug_req = $req->clone;
        $debug_req->header('Authorization' => 'Bearer [REDACTED]');
        $debug_req->header('x-api-key' => '[REDACTED]') if $debug_req->header('x-api-key');
        print STDERR "Request: " . $debug_req->as_string . "\n";
    }
    
    # Send the request
    my $res = $self->{user_agent}->request($req);
    
    # Debug logging
    if ($self->{debug}) {
        print STDERR "Response: " . $res->as_string . "\n";
    }
    
    # Handle errors
    unless ($res->is_success) {
        my $error = "API request failed: " . $res->status_line;
        if ($self->{debug}) {
            $error .= "\n\nResponse: " . $res->decoded_content;
        }
        croak $error;
    }
    
    # Parse response
    my $response_data = decode_json($res->decoded_content);
    
    # Different APIs have slightly different response formats
    my $content;
    
    if (exists $response_data->{choices}[0]{message}{content}) {
        # OpenAI format
        $content = $response_data->{choices}[0]{message}{content};
    } elsif (exists $response_data->{content}) {
        # Some alternative format
        $content = $response_data->{content};
    } else {
        # Unknown format, return the whole response
        $content = "Unrecognized response format: " . encode_json($response_data);
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
    
    # Check for scripts in response
    my $scripts = extract_scripts($content);
    
    # Execute scripts if found and requested
    if (@$scripts && ($params{execute_scripts} // 1)) {
        my @results;
        foreach my $script (@$scripts) {
            my $result = execute_script($self, $script, $params);
            push @results, $result;
            
            # Append execution results to the content if requested
            if ($params{append_results} // 1) {
                $content .= "\n\n--- Script Execution Results ---\n";
                $content .= "Exit code: " . $result->{exit_code} . "\n";
                $content .= "Output:\n" . $result->{stdout} . "\n";
                if ($result->{stderr}) {
                    $content .= "Errors:\n" . $result->{stderr} . "\n";
                }
            }
        }
        
        # Store execution results
        $self->{last_execution_results} = \@results;
    }
    
    return $content;
}

# Extract shebang scripts from text
sub extract_scripts {
    my ($text) = @_;
    my @scripts;
    
    # Match scripts starting with a shebang line
    # This regex handles scripts both inside markdown code blocks and standalone
    while ($text =~ /(^|\n)((#!\/[^\n]+\n(?:\s*(?:[^\n]+)\n)+))/gs) {
        my $script = $2;
        
        # Clean up markdown code blocks if present
        $script =~ s/^```\w*\n//;
        $script =~ s/\n```$//;
        
        # Ensure script starts with shebang
        if ($script =~ /^#!/) {
            push @scripts, $script;
        }
    }
    
    return \@scripts;
}

# Execute a script using the appropriate socket daemon
sub execute_script {
    my ($self, $script, $params) = @_;
    
    # Determine which socket to use based on model/provider
    my $provider = lc($self->{provider} || 'default');
    $provider =~ s/\s+/_/g;  # Replace spaces with underscores
    
    # Socket path
    my $socket_path = $params->{socket_path} || 
                      $ENV{"${provider}_SOCKET"} || 
                      "ai_sockets/$provider.sock";
    
    # Check if socket exists
    unless (-e $socket_path) {
        return {
            exit_code => -1,
            stdout => "",
            stderr => "Socket not found: $socket_path"
        };
    }
    
    # Connect to socket
    my $socket = IO::Socket::UNIX->new(
        Peer => $socket_path,
        Type => SOCK_STREAM
    );
    
    unless ($socket) {
        return {
            exit_code => -1,
            stdout => "",
            stderr => "Could not connect to socket: $!"
        };
    }
    
    # Send script to socket
    my $request = {
        script => $script,
        timeout => $params->{script_timeout} || 30
    };
    
    print $socket encode_json($request) . "\n";
    
    # Read response
    my $response_json = "";
    while (my $line = <$socket>) {
        $response_json .= $line;
        last if $line eq "\n";
    }
    
    close($socket);
    
    # Parse response
    my $response = eval { decode_json($response_json) };
    if ($@) {
        return {
            exit_code => -1,
            stdout => "",
            stderr => "Invalid response from executor: $@"
        };
    }
    
    # Handle execution error
    if ($response->{status} eq 'error') {
        return {
            exit_code => -1,
            stdout => "",
            stderr => $response->{error}
        };
    }
    
    return {
        exit_code => $response->{exit_code},
        stdout => $response->{stdout},
        stderr => $response->{stderr},
        log_file => $response->{log_file}
    };
}

# Reset conversation history
sub reset_conversation {
    my ($self, $args) = @_;
    
    $self->{conversation} = [];
    
    # If a system message is provided, initialize with it
    if ($args && $args->{system_message}) {
        $self->{conversation} = [{
            role => "system",
            content => $args->{system_message}
        }];
    }
    
    return $self;
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
