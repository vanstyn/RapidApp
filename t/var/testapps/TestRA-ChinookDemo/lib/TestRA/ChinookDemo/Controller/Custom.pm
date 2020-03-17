package # hide from PAUSE
     TestRA::ChinookDemo::Controller::Custom;

use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

use strict;
use warnings;

sub foo :Path('/foo') {
  my ($self, $c, @args) = @_;

  $c->res->content_type('text/plain');
  $c->res->body("This is user-defined :Path controller action '/foo'");
  return $c->detach;
}

1;
