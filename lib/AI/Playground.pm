#!/usr/bin/perl
# vim: ts=2 sw=2 ft=perl
eval 'exec perl -x -wS $0 ${1+"$@"}'
  if 0;
$|++;
package AI::Playground;
use common::sense;
use autodie;
use AI::Util;
use Path::Tiny;
use AI::Config qw(:all);
use AI::Conv;
use AnyEvent::Socket;;
use AnyEvent::Handle;;
our(@VERSION) = qw( 0 1 0 );

our(%self);
sub new {
  my ($class)=shift;
  my ($self)={ @_ };
  bless($self,$class);
  $self->{conv}//=AI::Conv->new;
  $self->{host}//=undef;
  ($self->{port})//=map { split } qx( id -u );
  $self->{sock}=$self->mk_sock;
  $self;
};
sub run {
  AE::cv->recv;
}
my(@stuff);
sub mk_sock {
  my ($self)=shift;
  my ($host,$port) = map { $self->{$_} } qw(host port); 
  my ($serv);
  $serv=tcp_server $host, $port, sub {
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
        $DB::single=1;
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
  push(@stuff,$serv);
  return $serv;
};
1;
