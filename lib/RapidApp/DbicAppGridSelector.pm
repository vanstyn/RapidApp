package RapidApp::DbicAppGridSelector;
use strict;
use Moose;

extends 'RapidApp::AppGridSelector';
with 'RapidApp::Role::DbicLink';

use RapidApp::Include qw(sugar perlutil);


has '+get_ResultSet_Handler' => ( default => sub {
	my $self = shift;
	return RapidApp::Handler->new(
		scope	=> $self,
		method	=> 'get_ResultSet'
	);
});

sub get_ResultSet {
	my $self = shift;
	
	my $Rs = $self->ResultSource->resultset;
	return $Rs unless (defined $self->c->req->params->{id_in});
	
	my $in = $self->json->decode($self->c->req->params->{id_in});
	return $Rs->search({ 'me.' . $self->record_pk => { '-in' => $in }});
}


#no Moose;
#__PACKAGE__->meta->make_immutable;
1;