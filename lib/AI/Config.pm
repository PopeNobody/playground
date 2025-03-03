package AI::Config;

use strict;
use warnings;
use Exporter 'import';
use Nobody::Util;
use JSON::Pretty;
use Path::Tiny;

our @EXPORT_OK = qw(get_api_info get_api_key);

# Storage for model configuration
our %CONFIG;

# Load model config at initialization
BEGIN {
    my $file = path("etc/model.json");
    if ($file->exists) {
        my $json = $file->slurp;
        my $config = decode_json($json);
        %CONFIG = %$config;
    } else {
        die "Cannot find model configuration file: etc/model.json";
    }
}

# Get API info
sub get_api_info {
    return { %CONFIG };
}

# Get API key
sub get_api_key {
    return $ENV{API_KEY};
}

1;

