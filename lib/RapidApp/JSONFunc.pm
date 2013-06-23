package RapidApp::JSONFunc;
use strict;
use warnings;
use Moose;

# This object allows returning functions within JSON. To prevent the function from being
# quoted (i.e. turned into a string), this object must be encoded with RapidApp::JSON::MixedEncoder
# which extends JSON::PP and modifies the behavior to return TO_JSON_RAW as-is

use RapidApp::Include qw(sugar perlutil);
use RapidApp::JSON::MixedEncoder;

has 'func'		=> ( is => 'ro', required => 1, isa => 'Str' );
has 'parm'		=> ( is => 'ro', required => 0 );
has 'raw'		=> ( is => 'ro', default => 0 );

has 'json' => ( is => 'ro', lazy_build => 1 );
sub _build_json {
	my $self = shift;
	return RapidApp::JSON::MixedEncoder->new;
}

sub TO_JSON {
	my $self = shift;
	return $self->func if ($self->raw);
	return $self->func . '(' . $self->json->encode($self->parm) . ')';
}

sub TO_JSON_RAW {
	return (shift)->TO_JSON;
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
