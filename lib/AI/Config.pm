package AI::Config;

use strict;
use warnings;
use Exporter 'import';
use Nobody::Util;
use JSON::Pretty;
use Path::Tiny;

our @EXPORT_OK = qw(get_api_info get_api_key);

# Storage for model configuration
our %config;

# Load model config at initialization
BEGIN {
  *config = decode_json(path("etc/model.json")->slurp);
  die "missing API_KEY" unless defined $ENV{API_KEY};
  $config{dummy}=$config{api_key}=$ENV{API_KEY};
  $config{dummy} =~ s{.}{.}g;
}

# Get API key
sub get_api_key {
  return $config{api_key};
}
sub redact {
  return grep { s{$config{api_key}}{$config{dummy}}g } @_;
};
1;

