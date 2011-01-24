package RapidApp::DBIC::ResultSet::BaseConditions;
use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::ResultSet';

use RapidApp::Include qw(sugar perlutil);

sub c { RapidApp::ScopedGlobals->get('catalystInstance'); }

has 'base_search_conditions' => ( is => 'ro', default => undef );
has 'base_search_attrs' => ( is => 'ro', isa => 'Maybe[HashRef]', default => undef );

has 'override_search_rs' => ( is => 'ro', isa => 'Bool', default => 1 );

sub search_rs {
	my ($self, @args) = @_;
	
	return $self->SUPER::search_rs(@args) unless (
		$self->override_search_rs and 
		($self->base_search_conditions or $self->base_search_attrs)
	);
	
	my ($search,$attr) = @args;
	return $self->SUPER::search_rs(@args) if ($self->{attrs}->{BaseConditions});
	$attr = {} unless ($attr);
	$attr->{BaseConditions}++;
	
	my $ResultSet = $self->SUPER::search_rs($self->base_search_conditions,$self->base_search_attrs);
	return $ResultSet->SUPER::search_rs($search,$attr);
}


1;
