package RapidApp::AppCombo;


use strict;
use Moose;
with 'RapidApp::Role::DataStore';
extends 'RapidApp::AppBase';

use RapidApp::ExtJS::StaticCombo;

has 'name' 					=> ( is => 'ro', required => 1, isa => 'Str' );
has 'displayField' 		=> ( is => 'ro', required => 1, isa => 'Str' );
has 'valueField' 			=> ( is => 'ro', required => 1, isa => 'Str' );
has 'fieldLabel' 			=> ( is => 'ro', lazy => 1, default => sub { (shift)->name } );
has 'combo_id' 			=> ( is => 'ro', lazy => 1, default => sub { 'appcombo-' . String::Random->new->randregex('[a-z0-9A-Z]{5}') } );
has 'combo_baseconfig' 	=> ( is => 'ro', default => sub {{}} );


sub content {
	my $self = shift;

	my $base = $self->combo_baseconfig;

	my $cnf = {
		name 				=> $self->name,
		id 				=> $self->combo_id,
		fieldLabel 		=> $self->fieldLabel,
		allowBlank 		=> \0,
		width 			=> 337,
		store 			=> $self->JsonStore,
		data 				=> undef,
		displayField 	=> $self->displayField,
		valueField 		=> $self->valueField,
		mode 				=> 'remote',
		typeAhead 		=> \0,
	};
	
	foreach my $k (keys %$base) {
		$cnf->{$k} = $base->{$k};
	}
	
	return RapidApp::ExtJS::StaticCombo->new($cnf)->Config;
}



no Moose;
#__PACKAGE__->meta->make_immutable;
1;