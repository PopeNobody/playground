package AI::UI;
use base "Exporter";
use lib 'lib';
use common::sense;
use AI::Util;
use subs qw( run_script );
our($prompt_file, $conv, $edit, $res, $req );
our($edit,$user,$prompt_file,$conv)=(1, "nobody");
our(@EXPORT)=qw(
transact edit set_conv $conv $prompt_file $edit
run_script may_edit
);
if(0) {
  @_ = qw(IO::Socket::UNIX  IO::Socket);
  my ($fmt) = "%s->isa('%s')";
  for( qw( 0 1 ) ) {
    my ($code)=sprintf($fmt,@_);
    @_=reverse(@_);
    say "$code => ", (eval($code)?1:0);
    ddx([$@]) if($@);
  };
};

sub edit_and_transact {
  unless(defined($prompt_file)){
    $prompt_file=$conv->pair_name("prompt");
    $prompt_file=path($prompt_file->[0]);
  };
  if($conv->last->{role} eq "user") {
    $prompt_file->spew($conv->last->as_jwrap);
  };
  if($edit) {
    edit($prompt_file);
  };
  $conv->transact();
}
## This does a transaction on a conversation.  If
## the last message was from a user, it sends it,
## and adds the response to the converstaion.  If,
## otoh, it is from an AI, it prompts the user for
## a new prompt.
sub transact {
  die "you must creat and set a conv first!" unless defined($conv);
  my $res;
  if($conv->last->{role} eq "user") {
    # my last message did nto go out, maybe edit it first.
    $res = edit_and_transact;
  } elsif( $conv->last->role eq "system" ) {
    # system message was last, let's start something
    $res = edit_and_transact;
  } elsif( $conv->last->type eq "text/plain" ) { 
    # last thing seen was plain text from bot, let's
    # get him moving.
    $res = edit_and_transact;
  } elsif( $conv->last->type =~ m{^executable} ) {
    # we have a script to run, let's do it.
    $res = run_script;
  };
  return $res;
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
  if($edit) {
    edit($file);
  } else {
    say($file->slurp);
  };
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
  if($edit) {
    edit($capture);  
  };
  my ($msg) = AI::Msg->new("system","output",$capture->slurp);
  $conv->add($msg);
  $res=transact();
};
sub set_conv {
  if ( defined($conv) and $conv ne $_[0] and $_[0]ne$conv->file ) {
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
