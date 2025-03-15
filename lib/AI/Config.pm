package AI::Config;
use common::sense;
use Exporter 'import';
use lib 'lib';
use AI::Util;

our @EXPORT_OK = qw(
  get_api_info get_api_key get_api_ua get_api_mod get_api_url
);
{
  package AI::UserAgent;
  use parent 'LWP::UserAgent';
  sub new {
    my ($class,%args)=@_;
    $class->SUPER::new(%args);
  };
  sub request {
    my $self=shift;
    $DB::single=1;
    for($self->{_cookie_jar}) {
      $_->load() if defined;
    };
    my $req=shift;
    $DB::single=1;
    my $res=$self->SUPER::request($req);
    for($self->{_cookie_jar}) {
      $_->save() if defined;
    };
    return $res;
  };
}
# Storage for model configuration
our %config;

# Get API key
sub get_api_key {
  return $config{api_key};
}
sub get_api_mod {
  return $config{model};
};
sub get_api_ua {
  return $config{ua};
};
sub get_api_url {
  return $config{url}{api};
};
sub redact {
  shift if($_[0] eq __PACKAGE__);
  return grep { s{$config{api_key}}{$config{dummy}}g } @_;
};
BEGIN {
  my ($id) = map { split } qx(id -un);
  my $model = path("etc/")->child($id.".json");
  unless(-e $model) {
    ($model)=split("-",$ENV{API_MOD});
    $model=path("etc/")->child($model.".json");
  };
  say $model;
  *config = decode_json($model->slurp);
  if(defined($ENV{API_KEY}) and defined($ENV{API_MOD})) {
    $config{model}=$ENV{API_MOD};
    $config{dummy}=$config{api_key}=$ENV{API_KEY};
    delete $ENV{API_KEY} unless $^P;
    delete $ENV{API_MOD} unless $^P;
    $config{dummy} =~ s{.}{.}g;
    die "missing api key" unless defined get_api_key();
    die "No api_mod" unless defined get_api_mod();
    $config{ua}=AI::UserAgent->new();
    $config{ua}->default_header('Authorization' => "Bearer ".get_api_key() );
    $config{ua}->default_header('Content-Type' => 'application/json');
  } else {
    warn  (
      "API_MOD and API_KEY are required for communication\n".
      "entering debgaded mode\n"
    );
  };
}
BEGIN {
  print STDERR "\n\n\n",get_api_mod",\n\n\n";
};
1;

