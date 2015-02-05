package RapidApp::Module::DbicTmplPage;

use strict;
use warnings;

use Moose;
extends 'RapidApp::Module::StorCmp';
with 'RapidApp::Module::StorCmp::Role::DbicLnk::RowPg';

use RapidApp::Include qw(sugar perlutil);

use RapidApp::Module::DbicPropPage;

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

# if true, page will be wrapped into a tab panel with an extra "Data" tab (RapidApp::Module::DbicPropPage)
has 'tabify_data', is => 'ro', isa => 'Bool', default => 0;

has 'data_tab_class', is => 'ro', isa => 'Str', default => sub {'RapidApp::Module::DbicPropPage'};
has 'data_tab_params', is => 'ro', isa => 'HashRef', default => sub {{}};

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
      class => $self->data_tab_class,
      params => {
        defer_to_store_module => $self,
        ResultSource => $self->ResultSource,
        #get_ResultSet => $self->get_ResultSet, 
        TableSpec => $self->TableSpec,
        include_colspec => $self->include_colspec,
        updatable_colspec => $self->updatable_colspec,
        allow_restful_queries => $self->allow_restful_queries,
        get_local_args => sub { $self->local_args },
        $self->persist_all_immediately ? (
          persist_all_immediately => 1 
         ) : (
          persist_immediately => $self->persist_immediately 
        ),
        %{ $self->data_tab_params },
        onBUILD => sub {
          my $o = shift;
          # Turn off autoScroll because scrolling is handled by the parent
          $o->apply_extconfig( autoScroll => \0 );
          $self->data_tab_params->{onBUILD}->($o) if (exists $self->data_tab_params->{onBUILD});
        }
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
    autoWidth    => \1,
    items => [
      {
        title => $content->{title} || $content->{tabTitle} || 'Main',
        iconCls => $content->{iconCls} || $content->{tabIconCls} || 'ra-icon-application-view-detail',
        layout => 'anchor',
        autoHeight => \1,
        autoWidth => \1,
        closable => 0,
        items => $content,
      },
      {
        %{ $self->Module('data_tab')->content },
        title => 'Data',
        iconCls => 'ra-icon-database-table',
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
