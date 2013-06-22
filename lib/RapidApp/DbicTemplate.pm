package RapidApp::DbicTemplate;

use strict;
use Moose;
extends 'RapidApp::AppDataStore2';
with 'RapidApp::Role::DbicLink2', 'RapidApp::Role::DbicRowPage';

use RapidApp::Include qw(sugar perlutil);

use RapidApp::DbicAppPropertyPage;

has 'tt_file', is => 'ro', isa => 'Str', required => 1;

has 'tt_include_path' => ( 
	is => 'ro', 
	isa => 'Str', 
	lazy => 1,
	default => sub {
		my $self = shift;
    return $self->app->default_tt_include_path;
	}
);

# if true, page will be wrapped into a tab panel with an extra "Data" tab (RapidApp::DbicAppPropertyPage)
has 'tabify_data', is => 'ro', isa => 'Bool', default => 0;

has '+allow_restful_queries', default => 1;

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
				allow_restful_queries => $self->allow_restful_queries,
				get_local_args => sub { $self->local_args }
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
				iconCls => 'icon-database-table',
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
