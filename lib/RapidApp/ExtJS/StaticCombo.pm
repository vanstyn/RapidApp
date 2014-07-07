package RapidApp::ExtJS::StaticCombo;
#
# -------------------------------------------------------------- #
#

use strict;
use Moose;

extends 'RapidApp::ExtJS::ContainerObject';


our $VERSION = '0.1';

#### --------------------- ####

has 'name' 				=> ( is => 'ro', required => 1, isa => 'Str' );
has 'enum_list'		=> ( is => 'ro', required => 0, isa => 'ArrayRef' );

has 'xtype'				=> ( is => 'ro', default => 'combo' );
has 'typeAhead'		=> ( is => 'ro', default => 1 );
has 'mode'				=> ( is => 'ro', default => 'local' );
has 'triggerAction'	=> ( is => 'ro', default => 'all' );
has 'selectOnFocus'	=> ( is => 'ro', default => 1 );
has 'editable'			=> ( is => 'ro', default => 0 );

#has 'displayField' => ( is => 'ro', lazy => 1, default => sub {
#	my $self = shift;
#	return $self->name;
#});


has 'displayField'	=> ( is => 'ro', default => 'displayField' );


has 'valueField' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return $self->name;
});


has 'data' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my @a = ();
	
	foreach my $i (@{$self->enum_list}) {
		push @a,[$i,$i];
	}
	
	return \@a;
});

has 'store' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $field = { name => $self->name };
	
	return {
		xtype		=> 'arraystore',
		fields	=> [ $field, $self->displayField ],
		data		=> $self->data
	};
});



no Moose;
__PACKAGE__->meta->make_immutable;
1;