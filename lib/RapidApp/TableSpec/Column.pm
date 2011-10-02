package RapidApp::TableSpec::Column;
use strict;
use Moose;

use RapidApp::Include qw(sugar perlutil);

# This configuration class defines behaviors of tables and
# columns in a general way that can be used in different places



our $VERSION = '0.1';

has 'name' => ( is => 'ro', isa => 'Str', required => 1 );

#has 'header' => ( is => 'ro' );

#has 'label' => ( is => 'rw', isa => 'Str', lazy => 1, default => sub {
#	my $self = shift;
#	return $self->name;
#});

has 'order' => ( is => 'rw', isa => 'Maybe[Int]', default => undef, clearer => 'clear_order' );


has '_other_properties' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );



=pod
has 'limit_properties' => ( is => 'rw', isa => 'Maybe[ArrayRef[Str]]', default => undef, trigger => \&update_valid_properties );
has 'exclude_properties' => ( is => 'rw', isa => 'Maybe[ArrayRef[Str]]', default => undef, trigger => \&update_valid_properties );

has '_valid_properties_hash' => ( is => 'rw', isa => 'HashRef', default => sub {{}} );
sub update_valid_properties {
	my $self = shift;
	
	my @remove_cols = ();
	
	if (defined $self->limit_columns and scalar @{ $self->limit_columns } > 0) {
		my %map = map { $_ => 1 } @{ $self->limit_columns };
		push @remove_cols, grep { not defined $map{$_} } keys %{ $self->columns };
	}
	
	if (defined $self->exclude_columns and scalar @{ $self->exclude_columns } > 0) {
		my %map = map { $_ => 1 } @{ $self->exclude_columns };
		push @remove_cols, grep { defined $map{$_} } keys %{ $self->columns };
	}
	
	foreach my $remove (@remove_cols) {
		delete $self->columns->{$remove};
	}
}
=cut



sub set_properties {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $key (keys %new) {
		my $attr = $self->meta->get_attribute($key);
		if ($attr and $attr->has_write_method) {
			$self->$key($new{$key});
		}
		else {
			$self->_other_properties->{$key} = $new{$key};
		}
	}
}

sub all_properties_hash {
	my $self = shift;
	
	my $hash = { %{ $self->_other_properties } };
	
	foreach my $attr ($self->meta->get_all_attributes) {
		next if ($attr->name eq '_other_properties');
		next unless ($attr->has_value($self));
		$hash->{$attr->name} = $attr->get_value($self);;
	}
	return $hash;
}

# Returns a hashref of properties that match the list/hash supplied:
sub properties_limited {
	my $self = shift;
	my $map;
	
	if (ref($_[0]) eq 'HASH') 		{	$map = shift;								}
	elsif (ref($_[0]) eq 'ARRAY')	{	$map = { map { $_ => 1 } @{$_[0]} };	}
	else 									{	$map = { map { $_ => 1 } @_ };			}
	
	my $properties = $self->all_properties_hash;
	
	my @keys = grep { $map->{$_} } keys %$properties;
	
	my $set = {};
	foreach my $key (@keys) {
		$set->{$key} = $properties->{$key};
	}
	
	return $set;
}


sub copy {
	my $self = shift;
	my %opts = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	my %attr = ();
	my %other = ();
	
	foreach my $opt (keys %opts) {
		if ($self->meta->find_attribute_by_name($opt)) {
			$attr{$opt} = $opts{$opt};
		}
		else {
			$other{$opt} = $opts{$opt};
		}
	}
	
	my $Copy = $self->meta->clone_object(
		$self,
		%attr, 
		# This shouldn't be required, but is. The clone doesn't clone _other_properties!
		_other_properties => { %{ $self->_other_properties } }
	);
	
	$Copy->set_properties(%other);

	return $Copy;
}




no Moose;
__PACKAGE__->meta->make_immutable;
1;