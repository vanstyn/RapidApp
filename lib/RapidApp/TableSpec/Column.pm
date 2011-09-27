package RapidApp::TableSpec::Column;
use strict;
use Moose;

# This configuration class defines behaviors of tables and
# columns in a general way that can be used in different places



our $VERSION = '0.1';

has 'name' => ( is => 'ro', isa => 'Str', required => 1 );

has 'label' => ( is => 'rw', isa => 'Str', lazy => 1, default => sub {
	my $self = shift;
	return $self->name;
});



has '_other_properties' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );


sub set_properties {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	my $hash = \%new;
	
	foreach my $key (keys %$hash) {
		my $attr = $self->meta->get_attribute($key);
		if ($attr) {
			$self->$key($hash->{$key});
		}
		else {
			$self->_other_properties->{$key} = $hash->{$key};
		}
	}
}

sub all_properties_hash {
	my $self = shift;
	
	my $hash = { %{ $self->_other_properties } };
	
	foreach my $attr_name ($self->meta->get_attribute_list) {
		next if ($attr_name eq '_other_properties');
		$hash->{$attr_name} = $self->$attr_name;
	}
	return $hash;
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;