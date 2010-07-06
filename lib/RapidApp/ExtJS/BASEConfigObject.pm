package RapidApp::ExtJS::BASEConfigObject;
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


has '_additional_parameters' 						=> ( is => 'ro',	default => sub { {} },  isa => 'HashRef'					);
has '_exclude_attributes' 							=> ( is => 'ro',	default => sub { {} },  isa => 'HashRef'					);
has '_exclude_parameters' 							=> ( is => 'ro',	default => sub { {} },  isa => 'HashRef'					);


sub BUILD {}
after 'BUILD' => sub {
	my $self = shift;
	my $params = shift;
	
	foreach my $key (keys %$params) {
		next if (defined $self->meta->get_attribute($key) or defined $self->meta->get_method($key));
		next if (defined $self->_exclude_parameters->{$key});
		$self->_additional_parameters->{$key} = $params->{$key};
	}
};


sub Config {
	my $self = shift;
	
	my $config = {};
	
	foreach my $attr ( $self->meta->get_all_attributes ) {
		next if (
			$attr->name eq '_additional_parameters' or
			$attr->name eq '_exclude_attributes' or
			$attr->name eq '_exclude_parameters' or
			defined $self->_exclude_attributes->{$attr->name}
		);
		$config->{$attr->name} = $attr->get_value($self);
	}
	
	foreach my $key (keys %{$self->_additional_parameters}) {
		$config->{$key} = $self->_additional_parameters->{$key}
	}
	
	return $config;
}



no Moose;
__PACKAGE__->meta->make_immutable;
1;