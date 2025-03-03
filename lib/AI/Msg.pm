package AI::Msg;

use strict;
use warnings;
use lib 'lib';
use Nobody::Util;
use Path::Tiny;
use Data::Dumper;
use common::sense;
use builtin qw(blessed);
use Text::Wrap qw(wrap);

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
    $text=join("\n", flatten($text)) if ref($text) eq 'ARRAY';
    if(blessed($text) and $text->can("slurp")){
      $text=$text->slurp;
    };
    warn "$text is a ref" if ref($text);
    warn "$text is an existing filesystem object" if -e $text;
    my $self = {};
    $self->{role}=$role;
    $self->{text}=wrap("","",$text);
    $self->{name}=$name;
    bless $self, $class;
}

sub from_jwrap {
    my ($class, $data) = @_;
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
