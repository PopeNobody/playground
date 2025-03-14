package IO::File;
sub dbg {
};
package AI::Conv;
*dbg=*IO::File::dbg;

use lib "lib";
use strict;
use warnings;
use AI::Msg;
use AI::Util;
use Storable qw(nstore retrieve);
use Scalar::Util qw(blessed);
use Path::Tiny;
use Data::Dumper;
use Carp qw(confess croak carp cluck);
use common::sense;
use LWP::UserAgent;
use HTTP::Cookies::Netscape;
use AI::Config qw( get_api_key get_api_ua get_api_mod get_api_url);
# Add overloading for stringification to JSON
use overload '""' => sub { confess "don't stringify me bro!"; };

# Persistent user agent and API info

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
  my ($class, $dir, $file,$jar) = ( shift, shift);
  ($class) = ( ref($class) || $class );
  die "file is required" unless defined($dir);
  die "file should be Path::Tiny"  unless blessed($dir)
    and $dir->isa('Path::Tiny');
  $dir=$dir->absolute->mkdir;
  $file=$dir->child("conv.jwrap");
  $jar=$dir->child("cookies.txt");
  $jar=HTTP::Cookies::Netscape->new(file=>$jar);
  if(-e $jar->{file}){
    $jar->load;
  } else {
    $jar->save;
  };
  my $self={
    dir=>$dir,
    file => $file,
    msgs => [ ],
    jar => $jar,
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
    $DB::single=1;
    $self->add($msg);
  }

  return $self->check();
}
sub jar {
  my ($self)=shift;
  $self->{jar};
};
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
sub file {
  my ($self) = shift;
  $self->{file};
};
sub dir {
  my ($self)=shift;
  $self->{dir};
};
sub last {
  my ($self)=shift;
  my ($msgs)=$self->{msgs};
  my ($mcnt)=0+@{$msgs};
  print STDERR Dumper([$msgs, $mcnt]);
  $msgs->[$mcnt-1];
};
sub transact {
  my ($self) = @_;
  say STDERR ("self->".ref($self));
  croak "conv object required" unless blessed($self) && $self->isa('AI::Conv');

  # Prepare HTTP request
  my $req = HTTP::Request->new(POST => get_api_url()."/chat/completions");

  # Prepare payload with OpenAI format
  my $payload = {
    model => get_api_mod(),
    messages => [],
  };

  # Extract messages from conversation
  foreach my $msg (@{$self->{msgs}}) {
    push @{$payload->{messages}}, {
      role => $msg->{role},
      content => $msg->{text}
    };
  }

  my $json=encode_json($payload);
  $req->content($json);

  # Store redacted request for debugging
  my $disp = $req->as_string;
  $disp=AI::Config->redact($disp);
  my $uniq=serdate;
  $self->dir->child("ex.".$uniq.".req.log")->spew($disp);

  $DB::single=1;
  # Send request
  my $ua = get_api_ua();
  unless($ua->cookie_jar) {
    $ua->cookie_jar($self->jar);
  };
  my $res = get_api_ua()->request($req);
  $self->jar->save($self->jar->{file});
  # Store response for debugging
  $self->dir->child("ex.".$uniq.".res.log")->spew($res->as_string);

  # Handle errors
  unless ($res->is_success) {
    $self->jar->save;
    my $error = "API request failed: " . $res->status_line . "\n\n";
    $error .= "Request: $disp\n\n";
    $error .= "Response: " . $res->as_string;
    croak $error;
  }

  # Parse response
  my $response_data = decode_json($res->decoded_content);
  my ($reply);
  if(defined($response_data->{choices}[0]{message}{content})){
    $reply = $response_data->{choices}[0]{message}{content};
  }

  # Handle missing content
  unless (defined $reply and length $reply) {
    $reply = "No response content received from API. ".
    "Full response: " . $res->decoded_content
  }
  $DB::single=1;
  # Append AI response to conv
  my $msg = AI::Msg->new({
      role => "assistant",
      name => get_api_mod,
      text => $reply
    });
  $self->add($msg);

  return $msg;
}
1;
