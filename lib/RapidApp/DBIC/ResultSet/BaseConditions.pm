package RapidApp::DBIC::ResultSet::BaseConditions;
use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::ResultSet';

use RapidApp::Include qw(sugar perlutil);
use Clone;

##
##
##
##
##    DEPRICATED  - use RapidApp::DBIC::ResultSet::BaseRs instead
##
##
##
##


around 'BUILDARGS' => sub {
	my ($orig, $class, @args)= @_;
	# The correct parameters are a ResultSource, and args hash.
	# Some versions of some DBIC packages pass only a ResultSource.
	# If the arg hash is missing, NonMoose won't work its magic, and the program dies.
	# So, for maximum compatibility, we add an empty arg hash if it is missing.
	if (scalar(@args) == 1 && blessed($args[0]) && $args[0]->isa('DBIx::Class::ResultSource')) {
		push @args, {};
	}
	$class->$orig(@args);
};

sub c { RapidApp::ScopedGlobals->get('catalystInstance'); }

has 'base_search_conditions' => ( is => 'ro', default => undef );

has 'base_search_attrs' => ( 
	is => 'ro', 
	traits => [ 'Hash' ],
	isa => 'HashRef', 
	default => sub {{}},
	handles => {
		apply_base_search_attrs		=> 'set',
		delete_base_search_attrs	=> 'delete',
	}
);

has 'base_search_joins' => ( 
	is => 'ro', 
	traits => [ 'Array' ],
	isa => 'ArrayRef', 
	default => sub {[]},
	handles => {
		add_base_search_joins	=> 'push',
		all_base_search_joins	=> 'elements',
		clear_base_search_joins	=> 'clear'
	}
);
after 'add_base_search_joins' => sub {
	my $self = shift;
	$self->apply_base_search_attrs( join => [ $self->all_base_search_joins ] );
};
after 'clear_base_search_joins' => sub {
	my $self = shift;
	$self->apply_base_search_attrs( join => [] );
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
	
	DEBUG(db => (ref $self) =>
		base_search_conditions => $self->base_search_conditions, "\n",
		base_search_attrs => $self->base_search_attrs, "\n",
		search => $search, "\n",
		attrs => $attr);
	
	# fix group-by columns requirement for strict mode
	# if ($self->base_search_attrs->{group_by} && $self->base_search_attrs->{columns}) {
		# my %grpCols= @{ $self->base_search_attrs->{group_by} }, (grep { !ref $_ } @{ $self->base_search_attrs->{columns} });
		# $self->base_search_attrs->{group_by}= [ keys %grpCols ];
	# }
	my $ResultSet = $self->SUPER::search_rs($self->base_search_conditions,$self->base_search_attrs);
	return $ResultSet->SUPER::search_rs($search,$attr);
}


1;
