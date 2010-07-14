package RapidApp::AppDataView::Store;


use strict;
use Moose;
#with 'RapidApp::Role::Controller';
extends 'RapidApp::DataStore';


has 'record_pk' => ( is => 'ro', default => 'id' );

has 'read_records_coderef' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return $self->parent_module->read_records_coderef;
});

has 'storeId' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return $self->parent_module->dv_id . '-store';
});

#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;