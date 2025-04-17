package AI::UI;
use lib 'lib';
use AI::Config qw (get_api_mod);
use AI::Util;
use base "Exporter";
use common::sense;
use subs qw( run_script );
our($user,$file,$conv,$res,$req)=(1, "nobody");
use Carp qw(confess croak carp cluck);
our(@EXPORT)=qw(
  transact edit set_conv $conv $file run_script may_edit
);

sub edit_and_transact {
  unless(defined($file)){
    $file=$conv->pair_name("prompt");
    $file=path($file->[0]);
  };
  if($conv->last->{role} eq "user") {
    $file->spew($conv->last->as_jwrap);
  };
  edit($file);
}
## This does a transaction on a conversation.  If
## the last message was from a user, it sends it,
## and adds the response to the converstaion.  If,
## otoh, it is from an AI, it prompts the user for
## a new prompt.
sub transact {
  die "you must creat and set a conv first!" unless defined($conv);
  if($conv->last->{role} eq "user") {
    # my last message did nto go out, maybe edit it first.
    edit_and_transact;
  } elsif( $conv->last->role eq "system" ) {
    # system message was last, let's start something
    edit_and_transact;
  } elsif( $conv->last->type eq "text/plain" ) { 
    # last thing seen was plain text from bot, let's
    # get him moving.
    edit_and_transact;
  } elsif( $conv->last->type =~ m{^executable} ) {
    # we have a script to run, let's do it.
    run_script;
  };
  $conv->transact();
}
sub transact2 {
  my ($self) = @_;
  croak "conv object required" unless blessed($self) && $self->isa('AI::Conv');

  my ($url)=get_api_url("chat");
  ddx({ url=>$url });
  for($url) {
    die "no comple: $_" unless /comple/;
    die "no http: $_" unless /^http/;
  };
  # Prepare HTTP request
  my $req = HTTP::Request->new(POST => $url);

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
  my $req_disp = $req->as_string;
  $req_disp=AI::Config->redact($req_disp);
  warn "$req_disp" if length($req_disp)<5;
  my $pair = $self->pair_name("req"); 
  path($pair->[0])->spew($req_disp);
  my $ua = get_api_ua();

  confess "in degraded mode -- cannot call out " unless defined($ua);

  $ua->cookie_jar($self->jar);
  my $res = get_api_ua()->request($req);
  $self->jar->save;
  # Store response for debugging
  my $res_disp=$res->as_string;
  warn "$res_disp" if length($res_disp)<5;
  path($pair->[1])->spew($res_disp);

  # Handle errors
  unless ($res->is_success) {
    my $error = "API request failed: " . $res->status_line . "\n\n";
    $error .= "Request:\n$req_disp\n\n";
    $error .= "Response:\n$res_disp\n\n";
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
  # Append AI response to conv
  my $msg = AI::Msg->new({
      role => "assistant",
      name => get_api_mod,
      text => $reply
    });
  $self->add($msg);

  return $msg;
}
sub edit($) {
  my ($file)=shift;
  ddx({file=>$file});
  system("exec >/dev/tty </dev/tty 2>&1; gvim -f  $file");
  die "editor returned error" if $?;
  return $file;
};
sub may_edit($) {
  my($file)=shift;
  # either edit the file or dump it so the user can
  # have a look.
  edit($file);
};
sub run_script {
  my ($names)=path($conv->pair_name("script"));
  my ($script,$capture)=map{path($_)}@{$names};    
  my ($msg) = $conv->last;
  my ($text) = map { "$_" } $msg->{text};
  ## remove backticks if present.
  for($text) {
    if(s{^\s*```.*\n}{}) {
      s{^```.*}{\n---\n}sm;
      if(substr($_,-5,0) ne "\n---\n"){
        die "closing backticks went without rest of crap" ;
      };
      substr($_,-5,0,"");
    };
    die "no shebang line!\n",pp($msg) unless substr($_,0,2)eq'#!';
    $script->spew($_);    
  };
  $script->chmod(0755);
  unless($script->is_absolute){
    $script="./$script";
  };
  system("bin/capture -f $capture $script");
  edit($capture);  
  my ($msg) = AI::Msg->new("system","output",$capture->slurp);
  $conv->add($msg);
};
sub set_conv {
  if ( defined($conv) and $conv ne $_[0] and $_[0] ne $conv->file ) {
    die "conv already running.  clear it first!";
  } elsif ( defined($conv) ) {
    return $conv;
  };
  ($conv)=@_;
  if(safe_isa($conv,'AI::Conv')){
    return $conv;
  };
  my ($last,@list)=(path("etc/agent-run.conv")->touchpath);
  chomp(@list=$last->lines);
  printf "loaded %d convs from list\n", scalar(@list),"\n";
  my ($fmt);
  if(@list){
    $fmt=$list[@list-1];
  };
  if( defined($fmt) and $fmt =~ /%\d+[dx]/ ) {
    pop(@list);
  } else {
    $fmt="dat/conv-%04d/";
  };
  if(defined($conv) && length($conv)){
    $conv=AI::Conv->new(path($conv));
    unshift(@list,$conv);
    for(0 .. @list-1) {
      delete $list[$_] if $list[$_] eq $conv;
    };
  } else {
    while(@list) {
      eval { $conv=AI::Conv->new(path($list[0])) };
      if (defined($conv)){
        last;
      } else {
        warn "failed: $@";
        shift @list;
      };
    };
    unless(defined($conv)){
      my $itr=serial_maker({
          fmt=>$fmt,
          max=>9999,
          min=>0,
          dir=>1
        }
      );
      $conv=$itr->();
      die "internal error" unless defined $conv;
      ddx({ "new" => $conv });
      $conv=$conv->{fn};
      ddx({ "new" => $conv });
      unshift(@list,$conv);
      $conv=AI::Conv->new(path($list[0]));
    };
    die "failed to make conv at all" unless defined $conv;
  };
  $last->spew(map { $_, "\n" } @list);
  printf "saved %d convs to list\n", scalar(@list),"\n";
  return $conv;
}
1;
