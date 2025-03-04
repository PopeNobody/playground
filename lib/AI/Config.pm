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
  my $file = path("etc/model.json");
  if ($file->exists) {
    my $json = $file->slurp;
    my $config = decode_json($json);
    %config = %$config;
  } else {
    die "Cannot find model configuration file: etc/model.json";
  }
}

# Get API info
sub get_api_info {
  return { %config };
}

# Get API key
sub get_api_key {
  return $ENV{API_KEY};
}
my ($DUMMY);
BEGIN {
  $DUMMY="$ENV{API_KEY}";
  $DUMMY =~ s{.}{*}g;
}
sub redact {
  return grep { s{$ENV{API_KEY}}{$DUMMY}g } @_;
};
1;

