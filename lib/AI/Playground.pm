#!/usr/bin/perl
# vim: ts=2 sw=2 ft=perl
eval 'exec perl -x -wS $0 ${1+"$@"}'
  if 0;
$|++;
package AI::Playground;
use common::sense;
use autodie;
use AI::Util;
use Path::Tiny;
BEGIN {
  $ENV{API_KEY}="keykeykey";
  $ENV{API_MOD}="modmodmod";
};
use AI::Config qw(get_api_key get_api_ua get_api_url get_api_mod  );
use AI::Conv;
use AnyEvent::HTTPD;
use Data::Dumper;
use File::Temp qw(tempfile);
use HTTP::Request;
use HTML::Template;
use IO::Socket::UNIX;
use LWP::UserAgent;
our(@VERSION) = qw( 0 1 0 );

sub new {
  my ($class)=shift;
  my ($self) ={ @_ };
  bless($self,$class);
};
sub start {
  my ($self)=shift;
  say STDERR "starting $self";
  my $httpd = AnyEvent::HTTPD->new(port => $self->{port});
  $httpd->reg_cb (
    '/' => sub {
      my ($httpd, $req) = @_;

      $req->respond ({ content => ['text/html',
            path("html")->child("root.html")->slurp()
          ]});
    },
    '/test' => sub {
      my ($httpd, $req) = @_;

      $req->respond ({ content => ['text/html',
            "<html><body><h1>Test page</h1>"
            . "<a href=\"/\">Back to the main page</a>"
            . "</body></html>"
          ]});
    },
  );
  $self->{httpd} = $httpd;
};
