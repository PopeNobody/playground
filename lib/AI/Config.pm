package AI::Config;

use strict;
use warnings;
use Exporter 'import';
use AI::Util;
use LWP::UserAgent;

our @EXPORT_OK = qw(
  get_api_info get_api_key get_api_ua get_api_mod get_api_url
);

# Storage for model configuration
our %config;

our $UA;

# Get API key
sub get_api_key {
  return $config{api_key};
}
sub get_api_mod {
  return $config{model};
};
sub get_api_ua {
  return $UA;
};
sub get_api_url {
  return $config{url}{api};
};
sub redact {
  return grep { s{$config{api_key}}{$config{dummy}}g } @_;
};
BEGIN {
  my $model = path("etc/model.json");
  unless($model->exists) {
    system("ln -sf \$(id -un).json etc/model.json");
  };
  *config = decode_json($model->slurp);
  if(defined($ENV{API_KEY}) and defined($ENV{API_MOD})) {
    $config{dummy}=$config{api_key}=$ENV{API_KEY};
    delete $ENV{API_KEY} unless $^P;
    $config{dummy} =~ s{.}{.}g;
    die "missing api key" unless defined get_api_key();
    die "No api_mod" unless defined get_api_mod();
    $UA = LWP::UserAgent->new;
    $UA->default_header('Authorization' => "Bearer ".get_api_key() );
  } else {
    warn  (
      "API_MOD and API_KEY are required for communication\n".
      "entering debgaded mode\n"
    );
  };
}
1;

