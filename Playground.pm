package AI::Playground;

use strict;
use warnings;
use lib "lib";
use common::sense;
use autodie;
use AI::Util;
use Path::Tiny;
BEGIN {
  $ENV{API_KEY}="keykeykey";
  $ENV{API_MOD}="modmodmod";
};
use AI::Config qw(get_api_key get_api_ua get_api_url get_api_mod  );
use AI::Conv;
use AnyEvent::HTTPD;
use Data::Dumper;
use File::Temp qw(tempfile);
use HTTP::Request;
use HTML::Template;
use IO::Socket::UNIX;
use LWP::UserAgent;

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

#      # Basic web interface with form for input and response area
#      my $form = $self->_generate_form_html();

  # Initialize the HTTP server
  my $httpd = AnyEvent::HTTPD->new(port => $self->{port});
  $self->{httpd} = $httpd;

  # Register routes
  $httpd->reg_cb(
    # Root path shows the form
    '/' => sub {
      my ($httpd, $req) = @_;
      $self->root_form($httpd,$req);
    },
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

#    sub _generate_form_html {
#        my ($self) = @_;
#    
#        my $template_dir = path(".")->child('html');
#        my $template = HTML::Template->new(
#            filename => $template_dir->child('root.html')
#        );
#    
#        my $api_info = $self->{api_info};
#        $template->param(
#            instance_id       => $self->{instance_id},
#            model           => $self->{model},
#            api_url         => get_api_url(),    # Assuming get_api_url is still available
#            response_html   => '',
#            edit_field_value => '',
#        );
#    
#        return $template->output();
#    }


sub root_form {
    my ($self, $req) = @_;
    my ($m)=uc($req->{method});
    if($m eq "POST") {
      ddx( $req->{content} );
    } elsif ($m eq "GET") {
      my $temp_dir = path(".")->child('html');
      my $temp=HTML::Template->new(
        filename => $temp_dir->child('form.html')
      );
      $temp->param(
        instance_id       => $self->{instance_id},
        model             => $self->{model},
        api_url           => get_api_url(),
      );
      my $res = $temp->output();
      $req->respond({ content => ['text/html', $res ] });
    }
}
#          say STDERR "submission";
#          my $input = $req->parm('editField');
#    
#          unless (defined $input && $input =~ /\S/) {
#            $req->respond({ content => ['text/html', "No input received"] });
#            return;
#          }
#    
#          # Look for shebang scripts
#          my @scripts = $self->extract_scripts($input);
#          my $response_html = "";
#    
#          # First, process through AI if not already containing scripts
#          if (!@scripts) {
#            my $ai_response = $self->process_ai_request($input);
#            $response_html .= "<h3>AI Response (Model: $self->{model}):</h3>\n<pre>$ai_response</pre>\n";
#    
#            # Check if AI response contains scripts
#            @scripts = $self->extract_scripts($ai_response);
#            if (@scripts) {
#              $response_html .= "<h3>Found scripts in AI response:</h3>\n";
#            }
#          }
#    
#          # Execute any scripts found
#          if (@scripts) {
#            $response_html .= "<h3>Script Execution:</h3>\n";
#            foreach my $script (@scripts) {
#              my $result = $self->execute_script($script, $self->{instance_id});
#              $response_html .= "<h4>Script executed with exit code " . $result->{exit_code} . "</h4>\n";
#              $response_html .= "<pre>" . ($result->{output} || "No output") . "</pre>\n";
#    
#              # If this was from AI response, send the execution results back to AI
#              if (!$self->extract_scripts($input)) {
#                my $execution_feedback = "I executed your script and got the following output:\n\n```\n" .
#                ($result->{output} || "No output") .
#                "\n```\n\nExit code: " . $result->{exit_code};
#    
#                my $ai_feedback = $self->process_ai_request($execution_feedback, $self->{model});
#                $response_html .= "<h3>AI Feedback on Execution:</h3>\n<pre>$ai_feedback</pre>\n";
#              }
#            }
#          }
#    
#          # Update the form with the response and return it
#          my $template_dir = path(".")->child('html');
#          my $template = HTML::Template->new(
#            filename => $template_dir->child('form.html')
#          );
#          my $api_info = $self->{api_info};
#          $template->param(
#            instance_id       => $self->{instance_id},
#            model           => $self->{model},
#            api_url         => get_api_url(),    # Assuming get_api_url is still available
#            response_html   => $response_html,
#            edit_field_value => $input,
#          );
#          my $response_page = $template->output();
#    
#          $req->respond({ content => ['text/html', $response_page] });
#    
1;
# ABSTRACT: turns baubles into trinkets
