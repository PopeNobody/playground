package AI::Config;
use common::sense;
use Exporter 'import';
use lib 'lib';
use AI::Util;
use AI::UserAgent;

our @EXPORT_OK = qw(
  get_api_info get_api_key get_api_ua get_api_mod get_api_url
);
our %EXPORT_TAGS;
$EXPORT_TAGS{all}=[];
BEGIN {
  push(@{$EXPORT_TAGS{all}},@EXPORT_OK);
}
our %config;
our(%urls);
$urls{chat}="/chat/completions";
$urls{list}="/model";
$DB::single=1;
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
  if($ENV{API_LOCAL}){
    warn  (
      "API_MOD and API_KEY are required for communication\n".
      "entering debgaded mode\n"
    );
    return;
  };
  if(defined($ENV{API_MOD}) and defined($ENV{API_KEY})){
    return unless length($ENV{API_MOD});
    my ($api_mod)=$ENV{API_MOD};
    delete $ENV{API_MOD} unless $^P;

    my ($api_key)=$ENV{API_KEY};
    delete$ENV{API_KEY} unless $^P;

    my ($api_cfg)=$api_mod;
    my ($api_cfg)=map { m{^([^-]+)-(.*)} } $api_cfg;

    $api_cfg=path("etc/")->child($api_cfg.".json");
    *config = decode_json($api_cfg->slurp);
    $config{api_key}=$api_key;
    die "missing api key" unless defined get_api_key();
    die "No api_mod" unless defined get_api_mod();
    $config{ua}=AI::UserAgent->new( base=>get_api_url );
    $config{ua}->default_header('Authorization' => "Bearer ".get_api_key() );
    $config{ua}->default_header('Content-Type' => 'application/json');
    $config{ua}->default_header('user-agent' => 'curl/7.88.1');
  };
};

1;
