package RapidApp::Module::AppDV::RecAutoload;

use strict;
use warnings;

#ABSTRACT: provide objects that maintain a list of method names

use Moose;

our $AUTOLOAD;

has 'method_rec' => (
  traits    => [
    'Hash',
  ],
  is        => 'ro',
  isa       => 'HashRef[Str]',
  default   => sub { {} },
  handles   => {
     apply_method_rec  => 'set',
     all_method_recs => 'keys'
  },
);

has 'process_coderef' => ( is => 'ro', isa => 'Maybe[CodeRef]', default => undef );

sub AUTOLOAD {
  my $self = shift;
  
  my $method = (reverse(split('::',$AUTOLOAD)))[0];
  
  $self->apply_method_rec( $method => 1 );
  return $self->process_coderef->($method, @_) if ($self->process_coderef);
}


1;