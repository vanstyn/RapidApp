package RapidApp::DbicAppCombo2;
use strict;
use warnings;
use Moose;
extends 'RapidApp::AppCombo2';

use RapidApp::Include qw(sugar perlutil);

### TODO: Bring this into the fold with DbicLink. For now, it is simple enough this isn't really needed

has 'ResultSet' => ( is => 'ro', isa => 'Object', required => 1 );
has 'RS_condition' => ( is => 'ro', isa => 'Ref', default => sub {{}} );
has 'RS_attr' => ( is => 'ro', isa => 'Ref', default => sub {{}} );
has 'record_pk' => ( is => 'ro', isa => 'Str', required => 1 );

sub BUILD {
	my $self = shift;
	
	# Remove the width hard coded in AppCombo2 (still being left in AppCombo2 for legacy
	# but will be removed in the future)
	$self->delete_extconfig_param('width');
	
	$self->apply_extconfig(
		itemId	=> $self->name . '_combo',
		forceSelection => \1,
		editable => \0,
	);
}


sub read_records {
	my $self = shift;
	
	my $Rs = $self->get_ResultSet;
	
	my @rows = ();
	foreach my $row ($Rs->all) {
		my $data = { $row->get_columns };
		push @rows, $data;
	}

	return {
		rows => \@rows,
		results => scalar @rows
	};
}


sub get_ResultSet {
	my $self = shift;
	my $params = $self->c->req->params;
	
	# todo: merge this in with the id_in stuff in dbiclink... Superbox??
	return $self->ResultSet->search_rs({ $self->record_pk => $params->{valueqry} }) if (defined $params->{valueqry});
	return $self->ResultSet->search_rs($self->RS_condition,$self->RS_attr);
}



1;


