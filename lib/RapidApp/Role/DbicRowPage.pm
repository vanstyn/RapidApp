package RapidApp::Role::DbicRowPage;
use strict;
use Moose::Role;

use RapidApp::Include qw(sugar perlutil);

# Role for DbicLink2 modules that display a single Row instead of multiple rows
# logic moved out of DbicAppPropertyPage

requires '_ResultSet';

has 'getTabTitle', is => 'ro', isa => 'Maybe[CodeRef]', default => undef;
has 'getTabIconCls', is => 'ro', isa => 'Maybe[CodeRef]', default => undef;

sub supplied_id {
	my $self = shift;
	my $id = $self->c->req->params->{$self->record_pk};
	if (not defined $id and $self->c->req->params->{orig_params}) {
		my $orig_params = $self->json->decode($self->c->req->params->{orig_params});
		$id = $orig_params->{$self->record_pk};
	}
	return $id;
}

sub ResultSet {
	my $self = shift;
	my $Rs = shift;

	my $value = $self->supplied_id or return $Rs;
	return $Rs->search_rs($self->record_pk_cond($value));
}

has 'req_Row', is => 'ro', lazy => 1, traits => [ 'RapidApp::Role::PerRequestBuildDefReset' ], default => sub {
#sub req_Row {
	my $self = shift;
	my $Rs = $self->_ResultSet;
	
	my $supId = $self->supplied_id;
	die usererr "Record Id not supplied in request", title => 'Id not supplied'
		unless ($supId || $self->c->req->params->{rest_query});
	
	my $count = $Rs->count;
	
	unless ($count == 1) {
		my $idErr = $supId ? "id: '$supId'" : "'" . $self->c->req->params->{rest_query} . "'";

		die usererr 'Record not found by ' . $idErr, title => 'Record not found'
			unless ($count);
		
		die usererr $count . ' records match ' . $idErr , title => 'Multiple records match';
	}
	
	my $Row = $Rs->first or return undef;
	
	if ($self->getTabTitle) {
		my $title = $self->getTabTitle->($self,$Row);
		$self->apply_extconfig( tabTitle => $title ) if ($title);
	}
	
	if ($self->getTabIconCls) {
		my $iconCls = $self->getTabIconCls->($self,$Row);
		$self->apply_extconfig( tabIconCls => $iconCls ) if ($iconCls);
	}
	  
	return $Row;
};



1;