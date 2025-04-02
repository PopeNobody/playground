package AI::UserAgent;
use lib 'lib';
use parent 'LWP::UserAgent';
use AI::Util;
sub new {
  my ($class,%args)=@_;
  my ($base)=delete $args{base};
  my ($urls)=delete $args{urls};
  my ($self)=$class->SUPER::new(%args);
  my (%data) = (
    class=>$class,
    base=>$base,
    urls=>$urls,
    self=>"$self",
  );
  ddx(\%data);
  die "no base" unless defined $base;
  die "no urls" unless defined $urls;
  die "no chat" unless defined $urls->{chat};
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
  $DB::single;
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
