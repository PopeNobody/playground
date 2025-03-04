package AI::Msg;

use strict;
use warnings;
use lib 'lib';
use Nobody::Util;
use Path::Tiny;
use Data::Dumper;
use Carp qw( confess carp croak cluck );
use common::sense;
use Scalar::Util qw(blessed);
use Text::Wrap qw(wrap $columns );
$columns=55;
{
  package
  Text;
  sub lines {
    return map { lines($_) } @_ unless 1==@_;
    local($_)=shift;
    if( ref eq 'GLOB' && defined(fileno($_)) ) {
      return <$_>;
    } elsif ( blessed($_) and $_->can("slurp") ) {
      return $_->slurp;
    } elsif ( ref eq 'ARRAY' ) {
      return lines(@$_);
    } else {
      return split(m{\n});
    };
  }
};
sub new {
    my ($class, $role, $name, $text) = @_;
    $_ = (ref || $_) for $class;
    die "class must be defined" unless defined $class;
    die "role must be defined" unless defined $role;
    die "name must be defined" unless defined $name;
    die "text must be defined" unless defined $text;
    $text=join("\n", flatten($text)) if ref($text) eq 'ARRAY';
    if(ref($text) eq 'ARRAY') {
      local(@_)=flatten($text);
      $text=join("\n",@_);
    };
    if(blessed($text) and $text->can("slurp")){
      $text=$text->slurp;
    };
    warn "$text is a ref" if ref($text);
    warn "$text is an existing filesystem object" if -e $text;
    my $self = { role=>$role, name=>$name, text=>$text };
    $text=wrap("","",$text);
    bless $self, $class;
}

sub from_jwrap {
    my ($class, $data) = @_;
    confess "$class must never be null" unless defined $class;
    confess "$data must not be mull" unless defined $data;
    confess "data->{role} not defined" unless defined $data->{role};
    confess "data->{name} not defined" unless defined $data->{name};
    confess "data->{text} not defined" unless defined $data->{text};
    ddx( [ ref($class), $class, $data ] );
    return $class->new($data->{role}, $data->{name}, $data->{text});
}

sub as_jwrap {
    my ($self) = @_;
    return {
        role => $self->{role},
        name => $self->{name},
        text => [ split(m{\n}, $self->{text}) ],
    };
}

1;
