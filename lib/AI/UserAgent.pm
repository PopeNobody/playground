package AI::UserAgent;
use lib 'lib';
use common::sense;
use AI::Config;
use parent 'LWP::UserAgent';
use Carp qw( carp confess croak cluck );
use AI::Util;
sub new {
  my ($class,%args)=@_;
  my ($self)=$class->SUPER::new(%args);
  $self;
};
sub base {
  return get_api_url();
};
our(%end);
sub url {
  return get_api_url(@_);
};
sub list_models {
  my $self=shift;
  my $url=$self->url("list");
  my $res=$self->get($url);
  ddx($res->content);
};
sub request {
  my $self=shift;
  for($self->{_cookie_jar}) {
    $_->load() if defined;
  };
  my $res=$self->SUPER::request(@_);
  my $req=shift;
  for($self->{_cookie_jar}) {
    $_->save() if defined;
  };
  return $res;
};
1;
