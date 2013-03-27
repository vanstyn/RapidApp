package RapidApp::JSONFunc;
#
# -------------------------------------------------------------- #
#


use strict;
use warnings;
use Moose;

use RapidApp::Include qw(sugar perlutil);

use JSON::PP;

our $VERSION = '0.1';


BEGIN {

	# We need to do this so that JSON won't quote the output of our
	# TO_JSON method and will allow us to return invalid JSON...
	# In this case, we're actually using the JSON lib to generate
	# JavaScript (with functions), not JSON

	#############################################
	#############################################
	######     OVERRIDE JSON::PP CLASS     ######
	use Class::MOP::Class;
	my $json_meta = Class::MOP::Class->initialize('JSON::PP');
	$json_meta->add_around_method_modifier(object_to_json => sub {
		my $orig = shift;
		my ($self, $obj) = @_;
		
		my $type = ref($obj);
		

		# Convert \'NULL' into undef (this came up after switing from MySQL to SQLite??)
		$obj = undef if ($type eq 'SCALAR' && $$obj eq 'NULL');
		
		# FIXME: This is another SQLite-ism: There are probably more
		$obj = undef if ($type eq 'SCALAR' && $$obj eq 'current_timestamp');
		
		return $orig->($self,$obj) unless (
			$type and
			$type eq __PACKAGE__ and
			$obj->can('TO_JSON')
		);
		
		return $obj->TO_JSON;

	}) unless $json_meta->get_method('object_to_json')->isa('Class::MOP::Method::Wrapped');
	######     OVERRIDE JSON::PP CLASS     ######
	#############################################
	#############################################
}


has 'func'		=> ( is => 'ro', required => 1, isa => 'Str' );
has 'parm'		=> ( is => 'ro', required => 0 );
has 'raw'		=> ( is => 'ro', default => 0 );

has 'json' => ( is => 'ro', lazy_build => 1 );
sub _build_json {
	my $self = shift;
	return JSON::PP->new->allow_blessed->convert_blessed;
}

sub TO_JSON {
	my $self = shift;
	return $self->func if ($self->raw);
	return $self->func . '(' . $self->json->encode($self->parm) . ')';
}

sub TO_JSON_RAW {
	return (shift)->TO_JSON;
}


#### --------------------- ####




no Moose;
__PACKAGE__->meta->make_immutable;
1;
