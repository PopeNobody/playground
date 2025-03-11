package IO::File;
sub dbg {
};
package AI::Conv;
*dbg=*IO::File::dbg;

use lib "lib";
use strict;
use warnings;
use AI::Msg;
use Storable qw(nstore retrieve);
use Nobody::Util;
use Scalar::Util qw(blessed);
use Nobody::JSON;
use Path::Tiny;
use Data::Dumper;
use Carp qw(confess croak carp cluck);
use common::sense;
use LWP::UserAgent;
use AI::Config qw( get_api_key get_api_ua get_api_mod get_api_url);
# Add overloading for stringification to JSON
use overload '""' => sub { confess "don't stringify me bro!"; };

# Persistent user agent and API info
sub file {
  my ($self) = shift;
  $self->{file};
};

sub check {
  my ($self)=shift;
  die "check: self is null" unless defined($self);
  die "check: not blessed" unless blessed($self);
  die "check: not blessed right" unless $self->isa("AI::Conv");
  my ($file)=$self->{file};
  die "check: file is null" unless defined($file);
  die "check: file is not blessed" unless blessed($file);
  die "check: file is not blessed right" unless($file->isa("Path::Tiny"));
  for(@{$self->{msgs}}){
    die "check: msg is not a msg" unless $_->isa("AI::Msg");
  };
  return $self;
};

sub new {
  my ($class, $file) = ( shift, shift);
  ($class) = ( ref($class) || $class );
  die "file is required" unless defined($file);
  die "file should be Path::Tiny"  unless blessed($file)
    and $file->isa('Path::Tiny');
  $file=$file->absolute;
  my $self={
    file => $file,
    msgs => [ ],
  };
  bless $self, $class;
  if (-e $file) {
    say STDERR "Loading AI::Conv from $file";
    $self->load_jwrap();
  } else {
    say STDERR "File $file does not exist, creating new conversation.";
    my $path=path("etc/system-message.md");
    dbg( { path=>$path } );
    my $msg = AI::Msg->new({
      role => "system",
      name => "system",
      text => $path
    });
    dbg( { "ref(\$msg)"=>ref($msg) } );
    $self->add($msg);
  }

  return $self->check();
}

sub save_jwrap {
  my ($self,$file) = @_;
  $file //= $self->{file};
  $file->parent->mkpath;
  my $jwrap=$self->as_jwrap;
  $file->spew(encode_json($jwrap));
  return $self;
}

sub load_jwrap {
  my ($self) = @_;
  die "self must be defined" unless defined $self;
  die "self must be ref" unless ref($self);
  my ($file) = $self->{file};
  die "file must be defined" unless defined $file;
  die "file must be ref" unless ref($file);
  die "file must slurp" unless blessed($file) and $file->can("slurp");
  
  my $json;
  eval {
    $json = $file->slurp;
  };
  if ($@) {
    die "Failed to read file $file: $@";
  }
  
  my $data;
  eval {
    $data = decode_json($json);
  };
  if ($@) {
    die "Failed to parse JSON from $file: $@ ($json)";
  }

  # Handle special case for a single message
  if (!ref($data) eq 'ARRAY') {
    $data = [$data];
  }
  
  # Must have at least one message
  if (!@$data) {
    die "No messages found in $file";
  }
  
  # Handle last message separately
  my $last = pop(@$data);
  
  # Add all messages
  foreach my $raw (@$data) {
    my $msg = AI::Msg->from_jwrap($raw);
    $self->add($msg);
  }
  
  # Add the last message
  my $msg = AI::Msg->from_jwrap($last);
  $self->add($msg);
  
  return $self;
}

sub add {
  my ($self, $msg) = @_;
  confess "add should be called with an AI::Msg object" 
    unless safe_isa($msg, "AI::Msg");

  push @{$self->{msgs}}, $msg;
  $self->save_jwrap();
  return $self;
}

sub as_jwrap {
  my ($self) = @_;
  return [ map { $_->as_jwrap() } @{$self->{msgs}} ];
}

sub as_json {
  my ($self) = @_;
  my @standard_msgs;

  foreach my $msg (@{$self->{msgs}}) {
    push @standard_msgs, $msg->as_json;
  }

  return encode_json({
    messages => \@standard_msgs,
    model => get_api_mod(),
  });
}

# Initialize globals at module load time

sub transact {
  say STDERR "transact(",Dumper(\@_).")";
  my ($self, $msg) = @_;
  
  croak "conv object required" unless blessed($self) && $self->isa('AI::Conv');
  croak "API not initialized" unless get_api_ua();

  # Append user message to conv unless empty
  croak "Message is required" unless defined $msg;
  if(ref($msg) ne 'AI::Msg'){
    $msg = AI::Msg->new(
      {
        role => "user",
        name => "user",
        text => $msg
      }
    );
  };
  if(ref($msg) ne "AI::Msg"){
    die "bad msg: ", pp($msg), "\n";
  };
  $self->add($msg);
  say STDERR "=========\n",$self->as_json,"\n========\n";

  # Prepare HTTP request
  my $req = HTTP::Request->new(POST => get_api_url()."/chat/completions");
  $req->header('Content-Type' => 'application/json');

  # Prepare payload with OpenAI format
  my $payload = {
    model => get_api_mod(),
    messages => [],
    temperature => 0.7,
    max_tokens => 4096
  };

  # Extract messages from conversation
  foreach my $msg (@{$self->{msgs}}) {
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
  my $res = get_api_ua()->request($req);

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
  unless (defined $reply and length $reply) {
    $reply = "No response content received from API. ".
    "Full response: " . encode_json($response_data);
  }
  $DB::single=1;
  # Append AI response to conv
  my $msg = AI::Msg->new({
      role => "assistant",
      name => "ai",
      text => $reply
    });
  $self->add($msg);

  return $msg;
}
1;
