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
use AI::Util qw(ddx);
use AI::UserAgent;
use Scalar::Util qw( blessed );
use Carp qw( cluck confess carp croak );
our($inst);
sub self {
  return $inst if defined $inst;
  $inst=AI::Config->new;
  return $inst;
};
sub get_api_mod {
  return self->{mod};
};
sub get_api_ua {
  return self->{ua};
};
my (%url_path);
BEGIN {
  %url_path=(
    chat=>"/chat/completions",
    list=>"/models",
  );
}
sub get_api_url {
  shift if(blessed($_[0]));
  if(@_==0) {
    return self->{url};
  } elsif ( @_==1 ) {
    local($_)=shift;
    $_=$url_path{$_};
    ddx([$_]);
    die "no path for $_" unless defined $_;
    ($_)=join("/",self->{url},$_);
    s{//+}{/}g;
    s{/}{//};
    say STDERR;
    return $_;
  } else {
    confess "get_api_url(",pp(\@_),")";
  };
};
sub get_loc_host {
  return self->{host};
};
sub get_loc_port {
  return self->{port};
};
sub redact {
  local(@_)=@_;
  shift if(blessed($_[0]) and $_[0]->isa(__PACKAGE__));
  my ($key)=self->{key};
  my ($dum)=join("",$key,"");
  $dum=~s{.}{x}g;
  @_ = grep { s{$key}{$dum}g;1; } @_;
  local($")="";
  wantarray ? @_ : "@_";
};
sub new {
  my ($class)=shift;
  my ($self)={};
  print "new";
  if($ENV{API_LOCAL}){
    warn  (
      "API_URL, API_MOD and API_KEY are required for communication\n".
      "entering debgaded mode\n"
    );
    return $self;
  };
  for(qw( API_MOD API_PORT API_URL API_KEY API_HAND ) ) {
    die "\$ENV{$_} is not defined" unless defined $ENV{$_};
    my ($val)=$ENV{$_};
    delete $ENV{$_} unless $^P;
    for(lc($_)){
      s{^api_}{};
      $self->{$_}=$val;
    };
  };
  $self->{host}=undef;
  $self->{ua}=AI::UserAgent->new; 
  $self->{ua}->default_header('Authorization' => 
    join("", "Bearer ",$self->{key}));
  $self->{ua}->default_header('Content-Type' => 'application/json');
  $self->{ua}->default_header('user-agent' => 'curl/7.88.1');
  return bless($self,$class);
};

1;
