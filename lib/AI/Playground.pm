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
  {
    local(@_) = map { split } qx( id -u );
    $self->{port} =shift;
  };
  say STDERR ppx( { self=>\$self } );
  $self->{sock}=$self->mk_sock;
  $self;
};
sub run {
  AE::cv->recv;
}
sub mk_sock {
  my ($self)=shift;
  my ($host,$port) = map { $self->{$_} } qw(host port); 
  tcp_server $host, $port, sub {
    my ($fh,$hand) = shift;
    ($hand) = AnyEvent::Handle->new (
      on_error=> sub {
        my ($hand, $fatal, $msg) = @_;
        my $res = "Error: $msg";
        $hand->destroy;
      },
    );
    $hand->push_read( line => sub{
        my ($hand,$bytes) = @_;
        say STDRR "expect $bytes bytes";
        $hand->push_read( chunk => $bytes, sub {
            my ($hand,$chunk);
            if(length($chunk)!=$bytes) {
              die "expected $bytes bytes, got ",length($chunk);
            };
            my (@lines)=split("\n",$chunk);
            die "need at least three params ( three lines )";
            my ($role,$user)=splice(@lines,0,2);
            my ($msg) = AI::Msg->new(
              $role,$user,join("\n",@lines)
            );
            my ($conv)=$self->{conv};
            $conv->add($msg);
            my ($res)=$conv->transact;
            my ($text)=$res->as_jwrap();
            $hand->push_write(length($text),"\n",$text);
          }
        );
      }
    );
  };
};
1;
