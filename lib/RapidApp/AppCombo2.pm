package RapidApp::AppCombo2;
use Moose;
extends 'RapidApp::AppCmp';
with 'RapidApp::Role::DataStore2';

use strict;

use RapidApp::Include qw(sugar perlutil);


has 'name' 					=> ( is => 'ro', required => 1, isa => 'Str' );
has 'displayField' 		=> ( is => 'ro', required => 1, isa => 'Str' );
has 'valueField' 			=> ( is => 'ro', required => 1, isa => 'Str' );
has 'fieldLabel' 			=> ( is => 'ro', lazy => 1, default => sub { (shift)->name } );

sub BUILD {
	my $self = shift;
	
	$self->apply_extconfig(
		xtype				=> 'combo',
		typeAhead		=> \0,
		mode				=> 'remote',
		triggerAction	=> 'all',
		selectOnFocus	=> \1,
		editable			=> \0,
		allowBlank 		=> \0,
		width 			=> 337,
		name 				=> $self->name,
		fieldLabel 		=> $self->fieldLabel,
		displayField 	=> $self->displayField,
		valueField 		=> $self->valueField,
	);
	
	$self->add_listener(
		afterrender => RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppCombo2.combo.afterrender_listener' )
	);
}



no Moose;
#__PACKAGE__->meta->make_immutable;
1;