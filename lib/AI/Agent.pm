package AI::Agent;
use AnyEvent;
use common::sense;
use FindLib qw(AI::Util);
use Carp qw(verbose);
use autodie;
use AI::Config qw(get_api_mod get_api_ua);
use AI::Conv;
use AI::UI;
use AI::Util;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::Log;
use AnyEvent;
use AE;
sub note {
  local(@_)=@_;
  @_ = split("\n",@_);
  say STDERR "note: => $_" for @_;
};
sub handle_prompt($) {
  note "conv: $conv ($_)" for @_;
};
sub new(@) {
  $DB::single=1;
  my ($class,%self)=@_;
  my ($self)=\%self;
  $self{cond}//= AnyEvent->condvar;
  note "info: created new instance";
  $self{model} //= get_api_mod;
  $self{agent} //= do {
    my $agent=get_api_ua;
    die "Session not configured" unless defined($agent);
    $agent
  };
  print "$self{model}";
  note "creating  tcp server\n";
  $self{serv} //= tcp_server $self{host}, $self{port}, sub {
    my ($fh, $host, $port) = @_;
    note("got connection: @_\n");
    my $hand;
    my $num;
    my $toggle;
    $hand = new AnyEvent::Handle (
      fh=>$fh,
      on_read => sub {
        local(@_)=@_;
        note("read: @_");
        my ($linelen)=0;
        while(1) {
          $linelen=index($hand->{rbuf},"\n");
          note("linelen: $linelen");
          if($linelen<0){
            return;
          };
          $linelen++;
          my ($line)=substr($hand->{rbuf},0,$linelen,"");
          note("line: $line");
          if($self{lines}) {
            push(@{$self{text}},$line);
            note("line: $line");
            if(--$self{lines}){
              note("expect $self{lines} more");
            } else {
              note("/recv complete");
              handle_prompt(join("",@{$self{text}}));
            };
            next;
          } elsif ( $line =~ m{^\s*$} ) {
            # say nothing, act natural
            next;
          } elsif ( $line =~ m{^\s*/recv\s+(\d*[1-9]\d*)\s+lines\s*$} ) {
            if($self{lines}=$1){
              $self{text}=[];
              $hand->push_write("/send $self{lines} lines\n");
              next;
            };
          }
          $hand->push_write(join("",
              "invalid syntax.  Reject\n",
              "   ",qquote($line),"\n"
            ));
        }
      },
      on_error => sub {
        local(@_)=@_;
        $_="error: $_" for @_;
        note( @_ );
      },
      on_eof => sub {
        local(@_)=@_;
        $_ = "eof $_" for @_ 
      },
    );
  };
  bless($self,$class);
};
sub start() {
  my ($self)=shift;
  my ($cond)=$self->{cond};
  $cond->recv;
};
sub url() {
  my ($self)=shift;
  my ($host)=$self->{host};
  my ($port)=$self->{port};
  return sprintf("tcpl://%s:%d",$host,$port);
};
1;
