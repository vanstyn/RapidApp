package RapidApp::DbicTemplate;

use strict;
use Moose;
extends 'RapidApp::AppDataStore2';
with 'RapidApp::Role::DbicLink2';

use RapidApp::Include qw(sugar perlutil);

has 'tt_include_path', is => 'ro', lazy => 1, default => sub { (shift)->app->config->{root}->stringify . '/templates' };
has 'tt_file', is => 'ro', isa => 'Str', required => 1;

sub BUILD {
	my $self = shift;
	
	$self->apply_extconfig(
		xtype => 'panel',
		layout => 'anchor',
		autoScroll => \1,
		#frame => \1,
	);
	
	$self->add_ONCONTENT_calls('apply_template');
}

sub apply_template {
	my $self = shift;
	$self->apply_extconfig( html => $self->render_template );
}


sub get_TemplateData {
	my $self = shift;
	return { row => $self->req_Row };
}

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

	my $value = $self->supplied_id;
	return $Rs->search_rs($self->record_pk_cond($value));
}

has 'req_Row', is => 'ro', lazy => 1, traits => [ 'RapidApp::Role::PerRequestBuildDefReset' ], default => sub {
#sub req_Row {
	my $self = shift;
	return $self->_ResultSet->first;
};



sub render_template {
	my $self = shift;
	
	my $html_out = '';
	my $tt_vars = $self->get_TemplateData;
	my $tt_file = $self->tt_file;
	
	my $Template = Template->new({ INCLUDE_PATH => $self->tt_include_path });
	$Template->process($tt_file,$tt_vars,\$html_out)
		or die $Template->error . "  Template file: $tt_file";
	
	return $html_out;
}



no Moose;
#__PACKAGE__->meta->make_immutable;
1;