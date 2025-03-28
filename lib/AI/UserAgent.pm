package AI::UserAgent;
use parent 'LWP::UserAgent';
sub new {
  my ($class,%args)=@_;
  $class->SUPER::new(%args);
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
