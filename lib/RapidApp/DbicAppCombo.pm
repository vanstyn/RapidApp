package RapidApp::DbicAppCombo;

use strict;
use warnings;
use Moose;
extends 'RapidApp::AppCombo';


use Term::ANSIColor qw(:constants);

has 'name'			=> ( is => 'ro', required => 1 );
has 'ResultSource' => ( is => 'ro', required => 1 );
has 'displayField'	=> ( is => 'ro', lazy => 1, default => sub { (shift)->name } );
has 'valueField'	=> ( is => 'ro', default => 'id' );

has 'store_use_xtype' => ( is => 'ro', default => 1 );

has 'no_persist'				=> ( is => 'rw',	default => 1 );

has 'fieldLabel'	=> ( is => 'ro', lazy => 1, default => sub { (shift)->name } );

has 'combo_baseconfig' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return {
		forceSelection => \1,
		hideLabel => \1,
		fieldLabel => $self->fieldLabel,
		editable => \0
	}
});


has 'store_autoLoad'		=> ( is => 'ro', default => sub {\0} );

has 'read_records_coderef' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return sub {
	
		my @r = $self->ResultSource->resultset->search()->all;
		
		my @rows = ();
		foreach my $row (@r) {
			push @rows, { $row->get_columns };
		}

		return {
			rows => \@rows,
			results => scalar @rows
		};
	};
#}
});

1;


