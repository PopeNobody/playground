package AI::Config;
use lib 'lib';
use Exporter qw(import);
our(@ISA)=qx(Exporter);
our(@EXPORT_OK)=(qw(
  get_api_info get_api_ua get_api_mod get_api_url
  get_loc_host get_loc_port
  )
);
use common::sense;
use Time::HiRes qw( time sleep );
use AI::Util;
use AI::UserAgent;
our($inst) = AI::Config->new;
sub self {
  return $inst if defined $inst;
  $inst=AI::Config->new;
  ddx($inst);
  return $inst;
};
sub get_api_mod {
  return self->{model};
};
sub get_api_ua {
  return self->{ua};
};
sub get_api_url {
  return self->{url}{api};
};
sub get_loc_host {
  return self->{host};
};
sub get_loc_port {
  return self->{port};
};
sub redact {
  shift if($_[0]->isa(__PACKAGE__));
  my ($key)=self->{api_key};
  my ($dum)=join("",$key,"");
  $dum=~s{.}{x}g;
  @_ = grep { s{$key}{$dum}g;1; } @_;
  local($")="";
  wantarray ? @_ : "@_";
};
sub new {
  my ($class)=shift;
  my ($self)={};
  if($ENV{API_LOCAL}){
    warn  (
      "API_URL, API_MOD and API_KEY are required for communication\n".
      "entering debgaded mode\n"
    );
    return $self;
  };
  for(qw( API_MOD API_URL API_KEY ) ) {
    die "$_ is not defined" unless defined $ENV{$_};
    my ($key)=lc($_);
    $self->{$key}=$ENV{$_};
    delete $ENV{$_} unless $^P;
  };
  my ($api_cfg)=$self->{api_mod};
  ($api_cfg)=map { m{^([^-]+)-(.*)} } $api_cfg;
  s{gemini}{gem}g for $api_cfg;
  @_=map { split } qx( id -u );
  $self->{host}=undef;
  $self->{port}=shift;
  $api_cfg=path("etc/")->child($api_cfg.".json");
  *config = decode_json($api_cfg->slurp);
  $self->{ua}=AI::UserAgent->new( 
      base=>$self->{api_url},
      urls=>{ chat=>"/chat/completions" }
    
  );
  $self->{ua}->default_header('Authorization' => 
    join("", "Bearer ",$self->{api_key}));
  $self->{ua}->default_header('Content-Type' => 'application/json');
  $self->{ua}->default_header('user-agent' => 'curl/7.88.1');
  return $self;
};

1;
