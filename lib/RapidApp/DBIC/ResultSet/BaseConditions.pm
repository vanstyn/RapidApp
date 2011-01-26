package RapidApp::DBIC::ResultSet::BaseConditions;
use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::ResultSet';

use RapidApp::Include qw(sugar perlutil);
use Clone;

sub c { RapidApp::ScopedGlobals->get('catalystInstance'); }

has 'base_search_conditions' => ( is => 'ro', default => undef );

has 'base_search_attrs' => ( 
	is => 'ro', 
	traits => [ 'Hash' ],
	isa => 'HashRef', 
	default => sub {{}},
	handles => {
		apply_base_search_attrs	=> 'set',
	}
);

has 'base_search_joins' => ( 
	is => 'ro', 
	traits => [ 'Array' ],
	isa => 'ArrayRef', 
	default => sub {[]},
	handles => {
		add_base_search_joins	=> 'push',
		all_base_search_joins	=> 'elements'
	}
);
after 'add_base_search_joins' => sub {
	my $self = shift;
	$self->apply_base_search_attrs( join => [ $self->all_base_search_joins ] );

};

has 'override_search_rs' => ( is => 'ro', isa => 'Bool', default => 1 );

sub BUILD {
	my $self = shift;
	
	if ($self->base_search_attrs->{join}) {
		if (ref($self->base_search_attrs) eq 'ARRAY') {
			$self->add_base_search_joins(@{$self->base_search_attrs->{join}});
		}
		else {
			$self->add_base_search_joins($self->base_search_attrs->{join});
		}
	}
}


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
