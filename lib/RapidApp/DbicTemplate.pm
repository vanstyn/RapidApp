package RapidApp::DbicTemplate;

use strict;
use Moose;
extends 'RapidApp::AppDataStore2';
with 'RapidApp::Role::DbicLink2';

use RapidApp::Include qw(sugar perlutil);

use RapidApp::DbicAppPropertyPage;

has 'tt_include_path', is => 'ro', lazy => 1, default => sub { (shift)->app->config->{root}->stringify . '/templates' };
has 'tt_file', is => 'ro', isa => 'Str', required => 1;

# if true, page will be wrapped into a tab panel with an extra "Data" tab (RapidApp::DbicAppPropertyPage)
has 'tabify_data', is => 'ro', isa => 'Bool', default => 0;

sub BUILD {
	my $self = shift;
	
	$self->apply_extconfig(
		xtype => 'panel',
		layout => 'anchor',
		autoScroll => \1,
		#frame => \1,
	);
	
	if($self->tabify_data) {
		$self->apply_init_modules( data_tab => {
			class => 'RapidApp::DbicAppPropertyPage',
			params => {
				ResultSource => $self->ResultSource,
				get_ResultSet => $self->get_ResultSet, 
				TableSpec => $self->TableSpec,
				include_colspec => $self->include_colspec,
			}
		});
	}
	
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

# Wrap with a tabpanel with the Data tab if "tabify_data" is true:
around 'content' => sub {
	my $orig = shift;
	my $self = shift;
	
	my $content = $self->$orig(@_);
	
	return $content unless ($self->tabify_data);
	
	my $tp = { 
		xtype => 'tabpanel',
		deferredRender => \0, # <-- If this it true (default) it screws up grids in non-active tabs
		activeTab => 0,
		autoHeight => \1,
		autoWidth		=> \1,
		items => [
			{
				title => $content->{title} || $content->{tabTitle} || 'Main',
				iconCls => $content->{iconCls} || $content->{tabIconCls} || 'icon-application-view-detail',
				layout => 'anchor',
				autoHeight => \1,
				autoWidth => \1,
				closable => 0,
				items => $content,
			},
			{
				%{ $self->Module('data_tab')->content },
				title => 'Data',
				iconCls => 'icon-database_table',
				layout => 'anchor',
				border => \0,
				autoHeight => \1,
				autoWidth => \1,
				closable => 0,
			},
		]
	};
	
	my $wrap = {
		frame => \0,
		bodyCssClass => 'x-panel-mc', #<-- same class as frame => \1
		bodyStyle => 'padding: 0;overflow-y:scroll;', #<-- override the 6px padding of x-panel-mc
		items => $tp
	};
	
	$wrap->{tabTitle} = $content->{tabTitle} if ($content->{tabTitle});
	$wrap->{tabIconCls} = $content->{tabIconCls} if ($content->{tabIconCls});
	
	return $wrap;
};


no Moose;
#__PACKAGE__->meta->make_immutable;
1;