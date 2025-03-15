package AI::Playground;

use strict;
use warnings;
use lib "lib";
use common::sense;
use autodie;
use AI::Util;
use Path::Tiny;
use LWP::UserAgent;
use HTTP::Request;
use AI::Config qw(get_api_key get_api_ua get_api_url get_api_mod  );
use File::Temp qw(tempfile);
use IO::Socket::UNIX;
use AnyEvent::HTTPD;
use Data::Dumper;

our $VERSION = '0.001';

=head1 NAME

AI::Playground - An evolving AI pipeline for code execution, HTTP requests, and multi-agent collaboration

=head1 SYNOPSIS

  use AI::Playground;

  # Start a playground server
  my $playground = AI::Playground->new(
    port => 4001,
    model => 'claude'
  );

  $playground->start;

=head1 DESCRIPTION

AI::Playground is a system that allows AI models to interact with your system through
a controlled environment. It can execute code provided by AI models, make HTTP requests,
compose emails, and facilitate multi-agent collaboration.

The system supports multiple AI models including Claude, GPT, Gemini, and Grok.

=head1 METHODS

=head2 new(%options)

Creates a new AI::Playground instance.

Options:
  * port - Port to listen on (default: user ID)
  * model - AI model to use (default: from API_MOD env var)
  * secure_mode - Enable additional security measures
  * script_log_dir - Directory to log scripts
  * log_dir - Directory for request/response logs
  * debug - Enable debug output

=cut

sub new {
  my ($class, %args) = @_;

  my $self = bless {
    port => $args{port},
    model => $args{model},
    secure_mode => $args{secure_mode},
    instance_id => $args{instance_id},
    script_log_dir => $args{script_log_dir} || "scr",
    log_dir => $args{log_dir} || "log",
    debug => $args{debug} || 0,
    socket_path => $args{socket_path} || "run",
  }, $class;

  # Initialize environment
  $self->_init_environment();

  return $self;
}

=head2 start()

Starts the AI Playground server. Returns the server object.

=cut

sub start {
  my ($self) = @_;

  print "Starting AI Playground Server for $self->{instance_id} on port $self->{port}...\n";

  #  my $comm_info = start_comm_server($self->{instance_id}, $self->{instance_type});
  #$self->{comm_info} = $comm_info;
  #print "Started communication server with ID: $self->{instance_id}\n";

  # Register message handlers
#      $self->_register_handlers();

  # Start HTTP server
  $self->_start_http_server();

  return $self;
}

=cut


Shows environment configuration.

=cut

sub _init_environment {
  my ($self) = @_;

  # Validate environment
  die "Environment incomplete. Required: API_KEY, API_MOD"
    unless get_api_ua;

  # Get API info based on model name
  my $api_info = $self->{model};

  # In secure mode, hide all potentially sensitive information
  if ($self->{secure_mode}) {
    $self->{debug} = 0 unless $ENV{DEBUG};
    # Redirect error output if needed
    if ($ENV{ERROR_LOG}) {
      open(STDERR, '>>', $ENV{ERROR_LOG}) or warn "Could not open error log: $!";
    }
  }

  # Create log directories
  path($self->{script_log_dir})->mkpath unless path($self->{script_log_dir})->exists;
  path($self->{log_dir})->mkpath unless path($self->{log_dir})->exists;
}

#    sub _register_handlers {
#      my ($self) = @_;
#    
#      register_handler('script_result', sub {
#          my $message = shift;
#          print "Received script result from " . $message->{sender}->{id} . "\n";
#          if ($self->{debug}) {
#            print "Script output: " . $message->{output} . "\n";
#          }
#        });
#    
#      register_handler('query', sub {
#          my $message = shift;
#          print "Received query from " . $message->{sender}->{id} . ": " . $message->{query} . "\n";
#    
#          # Process the query with our AI and send back results
#          if ($message->{expect_response}) {
#            my $response = $self->process_ai_request($message->{query}, $self->{model});
#            send_message($message->{sender}->{id}, {
#                type => 'response',
#                query_id => $message->{query_id},
#                response => $response
#              });
#          }
#        });
#    }
#    
=head2 _start_http_server()

Starts the HTTP server.

=cut

sub _start_http_server {
  my ($self) = @_;

  # Basic web interface with form for input and response area
  my $form = $self->_generate_form_html();

  # Initialize the HTTP server
  my $httpd = AnyEvent::HTTPD->new(port => $self->{port});
  $self->{httpd} = $httpd;

  # Register routes
  $httpd->reg_cb(
    # Root path shows the form
    '/' => sub {
      my ($httpd, $req) = @_;
      $req->respond({ content => ['text/html', $form] });
    },

    # Instance communication status page
    '/instances' => sub {
      my ($httpd, $req) = @_;
      $req->respond({ content => ['text/html', $self->_generate_instances_html()] });
    },

    # Handle form submissions
    '/submit' => sub {
      my ($httpd, $req) = @_;
      $self->_handle_form_submission($req);
    },

    # Forward a prompt to another AI
    '/forward' => sub {
      my ($httpd, $req) = @_;
      $self->_handle_forward_request($req);
    },

    # API endpoint for AI-to-AI communication
    '/ai_api' => sub {
      my ($httpd, $req) = @_;
      $self->_handle_ai_api_request($req);
    },

    # Inter-instance communication endpoint
    '/comm' => sub {
      my ($httpd, $req) = @_;
      $self->_handle_comm_request($req);
    }
  );

  return $httpd;
}

=head2 save_log($type, $content, $is_error)

Saves a request/response log with sensitive info redacted.

=cut

sub save_log {
  my ($self, $type, $content, $ai_model, $is_error) = @_;
  return if $self->{secure_mode} && !$ENV{LOG_IN_SECURE_MODE};

  # Create timestamp and filename using serdate
  my $date_str = serdate();
  my $log_dir = path("$self->{log_dir}/$date_str");
  $log_dir->mkpath unless $log_dir->exists;

  my $filename = serdate(time()) . "-$ai_model-$type";
  $filename .= "-error" if $is_error;
  my $log_file = path("$log_dir/$filename.log");

  # Redact sensitive information
  my $redacted = $content;
  $redacted =~ s/(api[-_]?key|token|authorization)(\s*[=:]\s*)[^\s&"']*/$1$2(REDACTED)/gi;
  $redacted =~ s/(Bearer|Basic)\s+[^\s"']*/$1 (REDACTED)/gi;

  # Save the log
  $log_file->spew($redacted);
  return $log_file;
}

=head2 log_http_exchange($req, $res, $ai_model)

Logs HTTP request and response.

=cut

sub log_http_exchange {
  my ($self, $req, $res, $ai_model) = @_;

  # Clone and redact the request
  my $req_clone = $req->clone;
  if ($req_clone->header('Authorization')) {
    $req_clone->header('Authorization', 'Bearer (REDACTED)');
  }
  if ($req_clone->header('x-api-key')) {
    $req_clone->header('x-api-key', '(REDACTED)');
  }

  # Save request log
  my $req_log = $self->save_log('request', $req_clone->as_string, $ai_model);

  # Save response log if we have one
  if ($res) {
    my $res_log = $self->save_log('response', $res->as_string, $ai_model, !$res->is_success);
    return ($req_log, $res_log);
  }
  return $req_log;
}

=head2 execute_script($script_content, $ai_user)

Executes a script with shebang.

=cut

sub execute_script {
  my ($self, $script_content, $ai_user) = @_;

  # Log the script
  my $dir = path("script")->mkdir;
  my $timestamp = serdate();
  my $script = $dir->child("script.$timestamp.scr"); 
  $script->spew($script_content);
  $script->chmod(0755); # Make executable
  my $logfile = $dir->child("script.$timestamp.log");


  system("bin/capture -f $logfile -- - $script");

  my $output = $logfile->slurp;
  $logfile->remove;
  $script->remove;

  return {
    output => $output,
    exit_code => $? >> 8,
    signal => $?%127,
    timestamp => $timestamp
  };
}

=head2 extract_scripts($text)

Detects and extracts shebang scripts from text.

=cut

sub extract_scripts {
  my ($self, $text) = @_;
  my @scripts;

  # Match scripts starting with a shebang line - handle various formats
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

  return @scripts;
}

=head2 process_ai_request($input, $ai_model)

Processes an AI request through the appropriate API.

=cut

sub process_ai_request {
  my ($self, $input) = @_;

  if ($self->{debug}) {
    say STDERR "Processing request with model: ".get_api_mod;
    say STDERR "Using API URL: " . get_api_url;
    # Don't log API_KEY for security
  }

  # Try to use the AI::Transact module for API interaction
  my $response;
  eval {
    require AI::Conv;
    require AI::Transact;
    require HTTP::Request;
    require LWP::UserAgent;
    AI::Transact->import('transact');

    my $conv_file = "conversation_$self->{instance_id}.jwrap";
    my $conv = AI::Conv->new(path($conv_file));

    # Hook into AI::Transact to capture requests/responses for logging
    # This assumes AI::Transact uses LWP::UserAgent internally
    my $orig_request = \&LWP::UserAgent::request;
    no warnings 'redefine';
    local *LWP::UserAgent::request = sub {
      my ($self_ua, $req) = @_;
      my $res = $orig_request->($self_ua, $req);
      $self->log_http_exchange($req, $res, $self->{instance_id});
      return $res;
    };

    $response = transact($self->{instance_id}, $conv, $input);
  };

  if ($@) {
    my $error = $@;
    # Sanitize error message to remove any API keys
    $error =~ s/(api[-_]?key|token)(\s*[=:]\s*)[^\s&]*/$1$2(REDACTED)/gi;
    print STDERR "Error using AI::Transact: $error\n" if $self->{debug};
    # Fallback to a mock response for testing
    $response = "This is a simulated response from $self->{instance_id} ($self->{model}).\n\n";
    $response .= "If you provide code with a shebang line, I'll execute it for you.";
  }

  return $response;
}

=head2 forward_to_ai($target_instance, $message)

Forwards a request to another AI instance.

=cut

sub forward_to_ai {
  my ($self, $target_instance, $message) = @_;

  my $target_port = getpwnam($target_instance) || $ENV{"${target_instance}_PORT"} || 4001;
  my $ua = LWP::UserAgent->new;

  print STDERR "Forwarding request to $target_instance on port $target_port\n" if $self->{debug};

  my $req = HTTP::Request->new(POST => "http://localhost:$target_port/ai_api");
  $req->header('Content-Type' => 'application/json');
  $req->header('Authorization' => "Bearer INTERNAL_TOKEN");
  $req->content(encode_json({
        model => $target_instance,
        message => $message
      }));

  my $res = $ua->request($req);
  if ($res->is_success) {
    return decode_json($res->decoded_content);
  } else {
    print STDERR "Error forwarding to $target_instance: " . $res->status_line . "\n" if $self->{debug};
    return { error => "Failed to forward request: " . $res->status_line };
  }
}

# Private methods for handling HTTP requests

sub _generate_form_html {
  my ($self) = @_;

  my $api_info = $self->{api_info};
  return q{
  <!DOCTYPE html>
  <html>
  <head>
  <title>AI Playground - } . $self->{instance_id} . q{</title>
  <style>
  body { font-family: Arial, sans-serif; margin: 20px; }
  textarea { width: 100%; font-family: monospace; }
  .output { border: 1px solid #ccc; padding: 10px; margin-top: 10px; background: #f5f5f5; }
  pre { white-space: pre-wrap; }
  </style>
  </head>
  <body>
  <h1>AI Playground - } . $self->{instance_id} . q{</h1>
  <p>Connected to } . $self->{model} . q{ via } . $api_info->{url}->{api} . q{</p>
  <form method="post" action="/submit">
  <h2>Input:</h2>
  <textarea id="editField" name="editField" rows="15" cols="80" placeholder="Enter your prompt or script here..."></textarea>
  <br>
  <input type="submit" value="Submit to AI">
  </form>
  <div id="output" class="output">
  <h2>Response:</h2>
  <div id="response"></div>
  </div>
  <p><a href="/instances">View AI Instances Communication</a></p>
  </body>
  </html>
  };
}

sub _generate_instances_html {
  my ($self) = @_;

  # Get a list of all instances
  my @instances;
  for my $socket_file (path("ai_sockets")->children) {
    next unless $socket_file =~ /\.sock$/;
    my $id = $socket_file->basename;
    $id =~ s/\.sock$//;

    push @instances, {
      id => $id,
      is_self => ($id eq $self->{instance_id}),
      socket => $socket_file->stringify
    };
  }

  my $instances_html = q{
  <!DOCTYPE html>
  <html>
  <head>
  <title>AI Playground - Instance Communication</title>
  <style>
  body { font-family: Arial, sans-serif; margin: 20px; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
  th { background-color: #f2f2f2; }
  .self { background-color: #e6f7ff; }
  .controls { margin: 20px 0; }
  </style>
  <script>
  function sendMessage() {
  const target = document.getElementById('targetInstance').value;
  const messageType = document.getElementById('messageType').value;
  const messageContent = document.getElementById('messageContent').value;

  fetch('/comm', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
  action: 'send',
  target: target,
  message: {
  type: messageType,
  content: messageContent
  }
  })
  })
  .then(response => response.json())
  .then(data => {
  alert(data.success ? 'Message sent successfully' : 'Failed to send message');
  });
  }

  function broadcastMessage() {
  const messageType = document.getElementById('broadcastType').value;
  const messageContent = document.getElementById('broadcastContent').value;

  fetch('/comm', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
  action: 'broadcast',
  message: {
  type: messageType,
  content: messageContent
  }
  })
  })
  .then(response => response.json())
  .then(data => {
  alert('Broadcast sent to ' + data.results.length + ' instances');
  });
  }

  function forwardPrompt() {
  const target = document.getElementById('forwardTarget').value;
  const prompt = document.getElementById('forwardPrompt').value;

  fetch('/forward', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
  target: target,
  prompt: prompt
  })
  })
  .then(response => response.json())
  .then(data => {
  if (data.error) {
  alert('Error: ' + data.error);
  } else {
  document.getElementById('forwardResult').textContent = data.response || "No response";
  document.getElementById('forwardResultSection').style.display = 'block';
  }
  });
  }
  </script>
  </head>
  <body>
  <h1>AI Playground - Instance Communication</h1>
  <p>Current instance: <strong>} . $self->{instance_id} . q{</strong> (Type: } . $self->{instance_type} . q{)</p>

  <h2>Active Instances</h2>
  <table>
  <tr>
  <th>Instance ID</th>
  <th>Status</th>
  <th>Socket Path</th>
  </tr>
  };

  foreach my $instance (@instances) {
  $instances_html .= "<tr" . ($instance->{is_self} ? " class='self'" : "") . ">";
  $instances_html .= "<td>" . $instance->{id} . "</td>";
  $instances_html .= "<td>" . ($instance->{is_self} ? "Self" : "Active") . "</td>";
  $instances_html .= "<td>" . $instance->{socket} . "</td>";
  $instances_html .= "</tr>";
  }

  $instances_html .= q{
  </table>

  <div class="controls">
  <h2>Send Message to Specific Instance</h2>
  <div>
  <label for="targetInstance">Target Instance:</label>
  <select id="targetInstance">
};

foreach my $instance (@instances) {
  next if $instance->{is_self};
  $instances_html .= "<option value='" . $instance->{id} . "'>" . $instance->{id} . "</option>";
}

$instances_html .= q{
</select>
</div>
<div>
<label for="messageType">Message Type:</label>
<input type="text" id="messageType" value="query" />
</div>
<div>
<label for="messageContent">Message Content:</label>
<input type="text" id="messageContent" size="50" />
</div>
<button onclick="sendMessage()">Send Message</button>
</div>

<div class="controls">
<h2>Forward Prompt to Another AI</h2>
<div>
<label for="forwardTarget">Target AI:</label>
<select id="forwardTarget">
};

foreach my $instance (@instances) {
  next if $instance->{is_self};
  $instances_html .= "<option value='" . $instance->{id} . "'>" . $instance->{id} . "</option>";
}

$instances_html .= q{
</select>
</div>
<div>
<label for="forwardPrompt">Prompt:</label>
<textarea id="forwardPrompt" rows="3" cols="50"></textarea>
</div>
<button onclick="forwardPrompt()">Forward Prompt</button>
<div id="forwardResultSection" style="display: none; margin-top: 10px; padding: 10px; border: 1px solid #ccc;">
<h3>Response:</h3>
<pre id="forwardResult"></pre>
</div>
</div>

<div class="controls">
<h2>Broadcast Message to All Instances</h2>
<div>
<label for="broadcastType">Message Type:</label>
<input type="text" id="broadcastType" value="notification" />
</div>
<div>
<label for="broadcastContent">Message Content:</label>
<input type="text" id="broadcastContent" size="50" />
</div>
<button onclick="broadcastMessage()">Broadcast Message</button>
</div>

<p><a href="/">Back to Main Interface</a></p>
</body>
</html>
};

return $instances_html;
}

sub _handle_form_submission {
  my ($self, $req) = @_;

  say STDERR "submission";
  my $input = $req->parm('editField');

  unless (defined $input && $input =~ /\S/) {
    $req->respond({ content => ['text/html', "No input received"] });
    return;
  }

  # Look for shebang scripts
  my @scripts = $self->extract_scripts($input);
  my $response_html = "";

  # First, process through AI if not already containing scripts
  if (!@scripts) {
    my $ai_response = $self->process_ai_request($input);
    $response_html .= "<h3>AI Response (Model: $self->{model}):</h3>\n<pre>$ai_response</pre>\n";

    # Check if AI response contains scripts
    @scripts = $self->extract_scripts($ai_response);
    if (@scripts) {
      $response_html .= "<h3>Found scripts in AI response:</h3>\n";
    }
  }

  # Execute any scripts found
  if (@scripts) {
    $response_html .= "<h3>Script Execution:</h3>\n";
    foreach my $script (@scripts) {
      my $result = $self->execute_script($script, $self->{instance_id});
      $response_html .= "<h4>Script executed with exit code " . $result->{exit_code} . "</h4>\n";
      $response_html .= "<pre>" . ($result->{output} || "No output") . "</pre>\n";

      # If this was from AI response, send the execution results back to AI
      if (!$self->extract_scripts($input)) {
        my $execution_feedback = "I executed your script and got the following output:\n\n```\n" . 
        ($result->{output} || "No output") . 
        "\n```\n\nExit code: " . $result->{exit_code};

        my $ai_feedback = $self->process_ai_request($execution_feedback, $self->{model});
        $response_html .= "<h3>AI Feedback on Execution:</h3>\n<pre>$ai_feedback</pre>\n";
      }
    }
  }

  # Update the form with the response and return it
  my $response_page = $self->_generate_form_html();
  $response_page =~ s/<div id="response"><\/div>/<div id="response">$response_html<\/div>/;
  $response_page =~ s/<textarea id="editField"[^>]*>.*?<\/textarea>/<textarea id="editField" name="editField" rows="15" cols="80">$input<\/textarea>/s;

  $req->respond({ content => ['text/html', $response_page] });
}

sub _handle_forward_request {
  my ($self, $req) = @_;

  # Parse the JSON request
  my $json;
  eval {
    $json = decode_json($req->content);
  };

  if ($@) {
    $req->respond({ code => 400, content => ['application/json', '{"error":"Invalid JSON"}'] });
    return;
  }

  my $target = $json->{target};
  my $prompt = $json->{prompt};

  unless ($target && $prompt) {
    $req->respond({ code => 400, content => ['application/json', '{"error":"Missing target or prompt"}'] });
    return;
  }

  # Forward to the specified AI
  my $result = $self->forward_to_ai($target, $prompt);

  $req->respond({ content => ['application/json', encode_json($result)] });
}

sub _handle_ai_api_request {
  my ($self, $req) = @_;

  # Create a pseudo HTTP request object for logging
  my $http_req = HTTP::Request->new(
    'POST',
    $req->uri,
    [ map { $_ => $req->headers->{$_} } keys %{$req->headers} ],
    $req->content
  );

  # Log the incoming request (without any response yet)
  $self->log_http_exchange($http_req, undef, $self->{instance_id});

  # Basic auth check - allow internal tokens for AI-to-AI communication
  my $auth_token = $req->headers->{'authorization'};
  unless ($auth_token && ($auth_token =~ /^Bearer (.+)$/ || $auth_token eq 'Bearer INTERNAL_TOKEN')) {
    my $error_response = { code => 401, content => ['application/json', '{"error":"Unauthorized"}'] };

    # Log the response
    my $http_res = HTTP::Response->new(401, 'Unauthorized');
    $http_res->content('{"error":"Unauthorized"}');
    $self->log_http_exchange($http_req, $http_res, $self->{instance_id});

    $req->respond($error_response);
    return;
  }

  # Get the JSON content
  my $content = $req->content;
  my $json;
  eval {
    $json = decode_json($content);
  };

  if ($@) {
    $req->respond({ code => 400, content => ['application/json', '{"error":"Invalid JSON"}'] });
    return;
  }

  my $message = $json->{message};
  my $response = { model => $self->{model} };

  # Check for scripts in the message
  my @scripts = $self->extract_scripts($message);

  if (@scripts) {
    my @results;
    foreach my $script (@scripts) {
      my $result = $self->execute_script($script, $self->{instance_id});
      push @results, {
        exit_code => $result->{exit_code},
        output => $result->{output},
        timestamp => $result->{timestamp}
      };
    }
    $response->{results} = \@results;
  } else {
    # Process with AI
    my $ai_response = $self->process_ai_request($message);
    $response->{response} = $ai_response;

    # Check if AI response has scripts
    my @ai_scripts = $self->extract_scripts($ai_response);
    if (@ai_scripts) {
      my @results;
      foreach my $script (@ai_scripts) {
        my $result = $self->execute_script($script, $self->{instance_id});
        push @results, {
          exit_code => $result->{exit_code},
          output => $result->{output},
          timestamp => $result->{timestamp}
        };
      }
      $response->{script_results} = \@results;
    }
  }

  # Create and log the response
  my $json_response = encode_json($response);
  my $http_res = HTTP::Response->new(200, 'OK');
  $http_res->content($json_response);
  $self->log_http_exchange($http_req, $http_res, $self->{instance_id});

  $req->respond({ content => ['application/json', $json_response] });
}
sub _handle_comm_request {
  my ($self, $req) = @_;

  # Require POST method
  unless ($req->method eq 'POST') {
    $req->respond({ code => 405, content => ['application/json', '{"error":"Method not allowed"}'] });
    return;
  }

  # Parse the JSON request
  my $json;
  eval {
    $json = decode_json($req->content);
  };

  if ($@) {
    $req->respond({ code => 400, content => ['application/json', '{"error":"Invalid JSON"}'] });
    return;
  }

  # Handle different communication actions
  my $action = $json->{action};
  my $result;

  if ($action eq 'send') {
    # Send a message to a specific instance
    my $target = $json->{target};
    my $message = $json->{message};

    unless ($target && $message && $message->{type}) {
      $req->respond({ code => 400, content => ['application/json', '{"error":"Missing target or message"}'] });
      return;
    }

    my $success = send_message($target, $message);
    $result = { success => $success ? JSON::true : JSON::false };
  }
  elsif ($action eq 'broadcast') {
    # Broadcast a message to all instances
    my $message = $json->{message};

    unless ($message && $message->{type}) {
      $req->respond({ code => 400, content => ['application/json', '{"error":"Missing or invalid message"}'] });
      return;
    }

    my $results = broadcast_message($message);
    $result = { results => $results };
  }
  else {
    $req->respond({ code => 400, content => ['application/json', '{"error":"Invalid action"}'] });
    return;
  }

  $req->respond({ content => ['application/json', encode_json($result)] });
}

1;
# ABSTRACT: turns baubles into trinkets
