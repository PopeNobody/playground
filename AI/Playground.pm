package AI::Playground;
use lib 'lib';
use AI::Config qw( get_loc_port );
use AI::Conv;
use AI::Util;
use AnyEvent::Socket;
use AnyEvent::Handle;
use autodie;
use common::sense;
our(@VERSION) = qw( 0 1 0 );

our(%self);
sub new {
  my ($class)=shift;
  my ($self)={ @_ };
  bless($self,$class);
  $self->{conv}//=AI::Conv->new;
  $self->{host}//=undef;
  $self->{port}=get_loc_port;
  $self->{sock}=$self->mk_sock;
  $self->{conv}//=AI::Conv->new;
  $self;
};
sub run {
  AE::cv->recv;
}
my(@stuff);
sub mk_sock {
  my($self)=shift;
  $self->{sock}=tcp_server undef, get_loc_port(), sub {
    my ($fh,$hand) = shift;
    ($hand) = AnyEvent::Handle->new (
      fh=>$fh,
      on_error=> sub {
        my ($hand, $fatal, $msg) = @_;
        my $res = "Error: $msg";
        $hand->destroy;
      },
    );
    push(@stuff,$hand);
    $hand->push_read( line => sub{
        my ($hand,$bytes) = @_;
        say STDRR "expect $bytes bytes";
        $hand->push_read( chunk => $bytes, sub {
            my ($hand,$chunk) = @_;
            if(length($chunk)!=$bytes) {
              die "expected $bytes bytes, got ",length($chunk);
            };
            my (@lines)=split(/(\n)/,$chunk);
            chomp(@lines);
            @lines=grep{length}@lines;
            ddx(\@lines);
            if(@lines<3) {
              die "need at least three params ( three lines )" ;
            };
            my ($role,$user)=splice(@lines,0,2);
            eex( { role=>$role, user=>$user });
            my ($msg) = AI::Msg->new(
              $role,$user,join("\n",@lines)
            );
            eex({msg=>$msg});
            my ($conv)=$self->{conv};
            $conv->add($msg);
            my ($res)=$conv->transact;
            my ($text)=$res->as_jwrap();
            $hand->push_write(join("\n",length($text),$text));
          }
        );
      }
    );
  };
  return $self->{sock};
};
1;
