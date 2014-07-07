package RapidApp::ExtJS::ConfigObject;
#
# -------------------------------------------------------------- #
#
#   -- Ext-JS Config Object
#
#
# 2010-04-16:	Version 0.1 (HV)
#	Initial development


use strict;
use Moose;


our $VERSION = '0.1';

#### --------------------- ####


has '_init_params' 					=> ( is => 'rw',	init_arg => undef,  						isa => 'HashRef'	);
has '_exclude_attributes' 			=> ( is => 'ro',	default => sub { {} }, 					isa => 'HashRef'	);
has '_param_hash' 					=> ( is => 'ro',	lazy_build => 1, init_arg => undef,	isa => 'HashRef'	);


sub _build__param_hash {
	my $self = shift;
	my $hashref = $self->_attribute_params;
	foreach my $k (keys %{$self->_init_params}) {
		$hashref->{$k} = $self->_init_params->{$k};
	}
	return $hashref;
}

sub BUILD {}
before 'BUILD' => sub {
	my $self = shift;
	$self->_init_params(shift);
	$self->_param_hash;
};


sub _attribute_params {
	my $self = shift;
	
	my $params = {};
	
	foreach my $attr ( $self->meta->get_all_attributes ) {
		next if (
			$attr->name eq '_init_params' or
			$attr->name eq '_param_hash' or
			$attr->name eq '_exclude_attributes' or
			defined $self->_exclude_attributes->{$attr->name}
		);
		$params->{$attr->name} = $attr->get_value($self);
	}
	return $params;
}



sub Config {
	my $self = shift;
	return $self->_param_hash;
}



no Moose;
__PACKAGE__->meta->make_immutable;
1;