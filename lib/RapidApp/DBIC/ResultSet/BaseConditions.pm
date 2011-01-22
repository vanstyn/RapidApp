package RapidApp::DBIC::ResultSet::BaseConditions;
use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::ResultSet';

use RapidApp::Include qw(sugar perlutil);

sub c { RapidApp::ScopedGlobals->get('catalystInstance'); }
has 'json' => ( is => 'ro', default => sub { RapidApp::JSON::MixedEncoder->new } );
has 'base_search_conditions' => ( is => 'ro', default => undef );

has 'base_joins' => ( 
	is => 'ro',
	traits => [ 'Array' ],
	isa => 'ArrayRef[Str|HashRef]', 
	default => sub {[]},
	handles => {
		all_base_joins		=> 'elements',
		has_no_base_joins 	=> 'is_empty',
	}
);

sub search_rs {
	my ($self, @args) = @_;
	
	return $self->SUPER::search_rs(@args) unless ($self->base_search_conditions);
	
	# Skip munging search_rs if our base_search_conditions have already been
	# embedded in this ResultSet object (this probably means a resultset
	# method was called that returned another resultset, we don't want to 
	# duplicate our custom changes in that case):
	return $self->SUPER::search_rs(@args) if (
		ref($self->{cond}) eq 'HASH' and
		ref($self->{cond}->{'-and'}) eq 'ARRAY' and
		ref($self->{cond}->{'-and'}->[0]) eq 'HASH' and
		$self->json->encode($self->{cond}->{'-and'}->[0]) eq $self->json->encode($self->base_search_conditions)
	);

	my ($search, $attr) = @args;
	
	$self->set_joins($attr);
	
	my $condition = $self->base_search_conditions;

	if (defined $search) {
		$search = { '-and' => [ $condition, $search ] };
	}
	else {
		$search = $condition;
	}
	
	return $self->SUPER::search_rs($search,$attr);
}


sub set_joins {
	my $self = shift;
	my $attr = shift;
	
	return if ($self->has_no_base_joins);
	
	my $base_joins = {};
	foreach my $join ($self->all_base_joins) {
		my $key = $join;
		$key = $self->json->encode($join) if (ref($join)); 
		$base_joins->{$key} = $join;
	}
	
	foreach my $rel ($self->cur_joins_list($attr->{join},$self->{attrs}->{join})) {
		my $key = $rel;
		$key = $self->json->encode($rel) if (ref($rel));
		delete $base_joins->{$key} if (defined $base_joins->{$key});
	}
	
	return unless (scalar keys %$base_joins > 0);

	$attr->{join} = [] unless (defined $attr->{join});

	# Any keys remaining here need to be added:
	foreach my $key (keys %$base_joins) {
		my $join = $base_joins->{$key};
		push @{$attr->{join}}, $join;
	}
	
	$attr->{join} = $attr->{join}->[0] if (scalar @{$attr->{join}} == 1);
}


sub cur_joins_list {
	my ($self,@list) = @_;
	
	my @new = ();
	foreach my $item (@list) {
		next unless (defined $item);
		if (ref($item) eq 'ARRAY') {
			push @new, @$item;
		}
		else {
			push @new, $item;
		}
	}
	return @new;
}

__PACKAGE__->meta->make_immutable;
1;
