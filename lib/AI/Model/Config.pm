package AI::ModelConfig;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(get_api_info get_all_models);

# Model configuration hash
our %MODEL_CONFIG = (
    # OpenAI models
    'gpt' => {
        type => 'bearer',
        format => 'openai',
        base_url => 'https://api.openai.com/v1',
        endpoint => 'chat/completions',
        provider => 'openai'
    },
    # Anthropic models
    'claude' => {
        type => 'x-api',
        format => 'anthropic',
        base_url => 'https://api.anthropic.com/v1',
        endpoint => 'messages',
        provider => 'anthropic'
    },
    # Google models
    'gemini' => {
        type => 'bearer',
        format => 'gemini',
        base_url => 'https://generativelanguage.googleapis.com/v1beta',
        endpoint => 'models/%s:generateContent', # %s will be replaced with actual model name
        provider => 'google'
    },
    # X.AI models
    'grok' => {
        type => 'bearer',
        format => 'xai',
        base_url => 'https://api.x.ai/v1',
        endpoint => 'chat/completions',
        provider => 'xai'
    }
);

# Get API info from model name
sub get_api_info {
    my ($model_name) = @_;
    
    # Extract model family prefix (e.g., "gpt" from "gpt-4o")
    my ($family) = $model_name =~ /^([^-]+)/;
    
    # Get config for this model family
    my $config = $MODEL_CONFIG{$family} || $MODEL_CONFIG{'gpt'}; # Default to GPT if unknown
    
    # Format endpoint if it contains a placeholder
    my $endpoint = $config->{endpoint};
    $endpoint =~ s/%s/$model_name/g;
    
    # Construct full URL
    my $url = "$config->{base_url}/$endpoint";
    
    return {
        auth_type => $config->{type},
        format => $config->{format},
        url => $url,
        provider => $config->{provider},
        family => $family,
        model => $model_name
    };
}

# Get all available model families
sub get_all_models {
    return keys %MODEL_CONFIG;
}

# Add a new model configuration
sub add_model_config {
    my ($family, $config) = @_;
    $MODEL_CONFIG{$family} = $config;
    return 1;
}

1;
