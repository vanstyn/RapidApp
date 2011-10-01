package RapidApp::DbicAppCombo2;
use strict;
use warnings;
use Moose;
extends 'RapidApp::AppCombo2';

use RapidApp::Include qw(sugar perlutil);

has 'ResultSet' => ( is => 'ro', isa => 'Object', required => 1 );

has '+DataStore_build_params' => ( default => sub {{
	store_use_xtype => 1
}});


sub BUILD {
	my $self = shift;
	
	$self->apply_extconfig(
		itemId	=> $self->name . '_combo',
		forceSelection => \1,
		editable => \0,
	);
}


sub read_records {
	my $self = shift;
	
	my @rows = ();
	foreach my $row ($self->ResultSet->all) {
		my $data = { $row->get_columns };
		push @rows, $data;
	}

	return {
		rows => \@rows,
		results => scalar @rows
	};
}



1;


