package AI::UserAgent;
use parent 'LWP::UserAgent';
our(%path);

our($self);
sub new {
  return $self if $self;
  unless($self){
    my ($class,%args)=@_;
    my ($base)=$args{base};
    my ($urls)=$args{urls};
    $self=$class->SUPER::new(%args);
    $self->{base} = ${base};
    $self->{urls} = ${urls};
  };
  $self;
};
sub base {
  return shift->{base};
};
our(%end);
sub url {
  my $self=shift;
  my $name=shift;
  my $urls=$self->{urls};
  my $base=$self->{base};
  URI->new("$base/$urls{$name}");
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
