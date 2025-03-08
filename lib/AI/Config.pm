package AI::Config;

use strict;
use warnings;
use Exporter 'import';
use Nobody::Util;
use JSON::Pretty;
use Path::Tiny;
use LWP::UserAgent;

our @EXPORT_OK = qw(get_api_info get_api_key get_api_ua);

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
  *config = decode_json(path("etc/model.json")->slurp);
  die "missing API_KEY" unless defined $ENV{API_KEY};
  $config{dummy}=$config{api_key}=$ENV{API_KEY};
#      delete $ENV{API_KEY};
  $config{dummy} =~ s{.}{.}g;
  die "missing api key" unless defined get_api_key();
  die "No api_mod" unless defined get_api_mod();
  ddx({API_URL=>get_api_url, MODEL=>get_api_mod});
  $UA = LWP::UserAgent->new;
  $UA->default_header('Authorization' => "Bearer ".get_api_key() );
  
}
1;

