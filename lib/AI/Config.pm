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
  shift if($_[0]->isa(__PACKAGE__));
  @_ = grep { s{$config{api_key}}{$config{dummy}}g;1; } @_;
  local($")="";
  wantarray ? @_ : "@_";
};
BEGIN {
  if(defined($ENV{API_MOD}) and defined($ENV{API_KEY})){
    return unless length($ENV{API_MOD});
    my ($id) = map { split } qx(id -un);
    my $model = path("etc/")->child($id.".json");
    unless(-e $model) {
      ($model)=split("-",$ENV{API_MOD});
      say "model=$model";
      $model="gem" if $model eq "gemini";
      $model=path("etc/")->child($model.".json");
    };
    *config = decode_json($model->slurp);
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
    $config{ua}->default_header('user-agent' => 'curl/7.88.1');
  } else {
    warn  (
      "API_MOD and API_KEY are required for communication\n".
      "entering debgaded mode\n"
    ) unless $ENV{API_LOCAL};
  };
}
1;

