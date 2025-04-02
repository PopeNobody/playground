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
BEGIN {
  unless(defined($ENV{API_MOD}) and defined($ENV{API_KEY})){
    die "KEY and MOD required"
  };
  unless(length($ENV{API_MOD})) {
    return;
  };
  $config{api_key}=$ENV{API_KEY};
  delete $ENV{API_KEY} unless $^P;
  $config{api_mod}=$ENV{API_MOD};
  delete $ENV{API_MOD} unless $^P;
  for(map{"$_"}$config{api_mod}) {
    s{-.*$}{};
    s{gemini}{gem};
    my(%cfg)=%{decode_json(path("etc/$_.json")->slurp)};
    for(keys %cfg){
      $config{$_}//=$cfg{$_};
    };
  };
  my($ua)=AI::UserAgent->new( base=>$config{url} );
  $ua->default_header('Authorization' => "Bearer $config{api_key}");
  $ua->default_header('Content-Type' => 'application/json');
  $ua->default_header('user-agent' => 'curl/7.88.1');
  $config{ua}=$ua;
};
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

1;
