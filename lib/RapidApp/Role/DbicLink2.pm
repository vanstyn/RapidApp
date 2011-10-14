package RapidApp::Role::DbicLink2;
use strict;
use Moose::Role;

use RapidApp::Include qw(sugar perlutil);
use RapidApp::TableSpec::Role::DBIC;

# Colspec attrs can be specified as simple arrayrefs
has 'include_colspec' => ( is => 'ro', isa => 'ArrayRef' );

has 'relation_sep' => ( is => 'ro', isa => 'Str', default => '__' );

has 'ResultSource' => (
	is => 'ro',
	isa => 'DBIx::Class::ResultSource',
	required => 1
);

has 'ResultClass' => ( is => 'ro', lazy_build => 1 );
sub _build_ResultClass {
	my $self = shift;
	my $source_name = $self->ResultSource->source_name;
	return $self->ResultSource->schema->class($source_name);
}

has 'TableSpec' => ( is => 'ro', isa => 'RapidApp::TableSpec', lazy_build => 1 );
sub _build_TableSpec {
	my $self = shift;
	my $TableSpec = RapidApp::TableSpec->with_traits('RapidApp::TableSpec::Role::DBIC')->new(
		name => $self->ResultClass->table,
		relation_sep => $self->relation_sep,
		ResultClass => $self->ResultClass,
		include_colspec => $self->include_colspec
	);
	
	return $TableSpec;
}




1;