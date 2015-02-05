package RapidApp::Module::Grid;

use strict;
use warnings;

use Moose;
extends 'RapidApp::Module::StorCmp';

use RapidApp::Include qw(sugar perlutil);

use Try::Tiny;
use RapidApp::Column;

#has 'record_pk'      => ( is => 'ro', default => 'id' );
#has 'DataStore_class'  => ( is => 'ro', default => 'RapidApp::Module::DatStor', isa => 'ClassName' );


has 'title' => ( is => 'ro', default => undef );
has 'title_icon_href' => ( is => 'ro', default => undef );

has 'open_record_class' => ( is => 'ro', default => undef, isa => 'Maybe[ClassName|HashRef]' );
has 'add_record_class' => ( is => 'ro', default => undef, isa => 'Maybe[ClassName|HashRef]' );

has 'open_record_via_rest', is => 'ro', isa => 'Bool', default => 1;
has 'open_record_rest_key', is => 'ro', isa => 'Maybe[Str]', default => undef;

# ---
# If true, a special "open" link column will be prepended to the column list. This is useful for clients
# that cannot double-click, such as iPads
has 'open_record_column', is => 'ro', isa => 'Bool', default => 1;
has 'open_record_column_hidden', is => 'ro', isa => 'Bool', default => 1;
# ---

# autoLoad needs to be false for the paging toolbar to not load the whole
# data set
has 'store_autoLoad' => ( is => 'ro', default => sub {\0} );

has 'add_loadContentCnf' => ( is => 'ro', default => sub {
  {
    title    => 'Add',
    iconCls  => 'ra-icon-add'
  }
});

has 'add_button_cnf' => ( is => 'ro', default => sub {
  {
    text    => 'Add',
    iconCls  => 'ra-icon-add'
  }
});

# Either based on open_record_class, or can be set manually in the constructor:
has 'open_record_url' => ( is => 'ro', isa => 'Maybe[Str]', lazy => 1, default => sub {
  my $self = shift;
  return $self->Module('item',1)->base_url if ($self->open_record_class);
  return undef;
});


# get_record_loadContentCnf is used on a per-row basis to set the 
# options used to load the row in a tab when double-clicked
# This should be overridden in the subclass:
sub get_record_loadContentCnf {
  my ($self, $record) = @_;
  
  local $_ = $record;
  my $display = $self->get_record_display->($self);
  %$record = %$_;
  
  $display = { title => $display } unless (ref $display);
  
  return $display;
}
has 'get_record_display' => ( is => 'ro', isa => 'CodeRef', lazy => 1, default => sub { sub { 
  my $self = shift;
  $self->record_pk . ': ' . $_->{$self->record_pk}
}});

has 'init_pagesize' => ( is => 'ro', isa => 'Int', default => 25 );
has '+max_pagesize' => ( default => 500 );
has 'use_column_summaries', is => 'ro', isa => 'Bool', default => 0;

# -- autosize columns options:
has 'use_autosize_columns',     is => 'ro', isa => 'Bool', default => 1;
has 'auto_autosize_columns',     is => 'ro', isa => 'Bool', default => 0;
has 'auto_autosize_columns_deep',   is => 'ro', isa => 'Bool', default => 0;
has 'autosize_hidden',         is => 'ro', isa => 'Bool', default => 0;
has 'autosize_maxwidth',       is => 'ro', isa => 'Int', default => 450;
# --

has 'allow_edit_frozen', is => 'ro', isa => 'Bool', default => 1;

sub BUILD {
  my $self = shift;
  
  if (defined $self->open_record_class) {
    $self->apply_init_modules( item => $self->open_record_class );
    
    # reach into the new sub-module and add a write listener to its store to
    # make it call our store.load() whenever it changes:
    ### Temp disabled because this can cause a big load/hit ##
    #$self->Module('item',1)->DataStore->add_listener( write => $self->DataStore->store_load_fn ) if (
    #  $self->Module('item',1)->isa('RapidApp::Module::StorCmp')
    #);
  }
  
  if (defined $self->add_record_class) {
    $self->apply_init_modules( add => $self->add_record_class );
    
    # reach into the new sub-module and add a write listener to its store to
    # make it call our store.load() whenever it changes:
    
    ### Temp disabled because this can cause a big load/hit ##
    #$self->Module('add',1)->DataStore->add_listener( write => $self->DataStore->store_load_fn ) if (
    #  $self->Module('add',1)->isa('RapidApp::Module::StorCmp')
    #);
  }
  
  
  $self->apply_extconfig(
    xtype            => 'appgrid2',
    pageSize          => $self->init_pagesize,
    maxPageSize        => $self->max_pagesize,
    stripeRows        => \1,
    columnLines        => \1,
    use_multifilters    => \1,
    gridsearch        => \1,
    gridsearch_remote    => \1,
    column_allow_save_properties => [qw(width hidden)], 
    use_column_summaries => $self->use_column_summaries ? \1 : \0,
    use_autosize_columns => $self->use_autosize_columns ? \1 : \0,
    auto_autosize_columns => $self->auto_autosize_columns ? \1 : \0,
    auto_autosize_columns_deep => $self->auto_autosize_columns_deep ? \1 : \0,
    autosize_hidden => $self->autosize_hidden ? \1 : \0,
    autosize_maxwidth => $self->autosize_maxwidth,
    allow_edit_frozen => $self->allow_edit_frozen ? \1 : \0,
    open_record_via_rest => $self->open_record_via_rest ? \1 : \0,
    open_record_url => $self->open_record_url,
    open_record_rest_key => $self->open_record_rest_key,
    open_record_column => $self->open_record_column ? \1 : \0,
    open_record_column_hidden => $self->open_record_column_hidden ? \1 : \0,
  );
  
  # The record_pk is forced to be added/included as a column:
  if (defined $self->record_pk) {
    $self->apply_columns( $self->record_pk => {} );
    push @{ $self->include_columns }, $self->record_pk if (scalar @{ $self->include_columns } > 0);
    #$self->meta->find_attribute_by_name('include_columns_hash')->clear_value($self);
    %{ $self->include_columns_hash } = ();
  }
  
  if (defined $self->open_record_url or defined $self->add_record_class) {
    $self->add_listener(  beforerender => RapidApp::JSONFunc->new( raw => 1, func => 
      'Ext.ux.RapidApp.AppTab.cnt_init_loadTarget' 
    ));
  }
  
  # -- Moved into Ext.ux.RapidApp.AppTab.AppGrid2Def:
  #if (defined $self->open_record_url) {
  #  $self->add_listener( rowdblclick => RapidApp::JSONFunc->new( raw => 1, func => 
  #    'Ext.ux.RapidApp.AppTab.gridrow_nav' 
  #  ));
  #}
  # --
  
  $self->apply_actions( save_search => 'save_search' ) if ( $self->can('save_search') );
  $self->apply_actions( delete_search => 'delete_search' ) if ( $self->can('delete_search') );
  
  $self->DataStore->add_read_raw_mungers(RapidApp::Handler->new( scope => $self, method => 'add_loadContentCnf_read_munger' ));
  
  $self->add_ONREQUEST_calls('init_onrequest');
  $self->add_ONREQUEST_calls_late('init_delete_enable');
}

sub init_onrequest {
  my $self = shift;
  
  $self->apply_extconfig( preload_quick_search => $self->c->req->params->{quick_search} )
    if (try{$self->c->req->params->{quick_search}});
  
  my $quick_search_cols = try{$self->c->req->params->{quick_search_cols}};
  if($quick_search_cols && $quick_search_cols ne '') {
    $quick_search_cols = lc($quick_search_cols);
    my @cols = split(/\s*,\s*/,$quick_search_cols);
    $self->apply_extconfig( init_quick_search_columns => \@cols );
  }
  
  # Added for #94:
  if(my $qs_mode = try{$self->c->req->params->{quick_search_mode}}) {
    $self->apply_extconfig( init_quick_search_mode => $qs_mode );
  }
  
  
  #$self->apply_config(store => $self->JsonStore);
  $self->apply_extconfig(tbar => $self->tbar_items) if (defined $self->tbar_items);
}



sub init_delete_enable {
  my $self = shift;
  if($self->can('action_delete_records') and $self->has_flag('can_delete')) {
  #if($self->can('action_delete_records')) {
    my $act_name = 'delete_rows';
    $self->apply_actions( $act_name => 'action_delete_records' );
    $self->apply_extconfig( delete_url => $self->suburl($act_name) );
  }
}




sub add_loadContentCnf_read_munger {
  my $self = shift;
  my $result = shift;
  
  # Add a 'loadContentCnf' field to store if open_record_class is defined.
  # This data is used when a row is double clicked on to open the open_record_class
  # module in the loadContent handler (JS side object). This is currently AppTab
  # but could be other JS classes that support the same API
  if (defined $self->open_record_url) {
    foreach my $record (@{$result->{rows}}) {
      my $loadCfg = {};
      # support merging from existing loadContentCnf already contained in the record data:
      $loadCfg = $self->json->decode($record->{loadContentCnf}) if (defined $record->{loadContentCnf});
      
      %{ $loadCfg } = (
        %{ $self->get_record_loadContentCnf($record) },
        %{ $loadCfg }
      );
      
      unless (defined $loadCfg->{autoLoad}) {
        $loadCfg->{autoLoad} = {};
        $loadCfg->{autoLoad}->{url} = $loadCfg->{url} if ($loadCfg->{url});
      }
      
      $loadCfg->{autoLoad}->{url} = $self->open_record_url unless (defined $loadCfg->{autoLoad}->{url});
      
      $record->{loadContentCnf} = $self->json->encode($loadCfg);
    }
  }
}


#around 'store_read_raw' => sub {
#  my $orig = shift;
#  my $self = shift;
#  
#  my $result = $self->$orig(@_);
#  
#  # Add a 'loadContentCnf' field to store if open_record_class is defined.
#  # This data is used when a row is double clicked on to open the open_record_class
#  # module in the loadContent handler (JS side object). This is currently AppTab
#  # but could be other JS classes that support the same API
#  if (defined $self->open_record_class) {
#    foreach my $record (@{$result->{rows}}) {
#      my $loadCfg = {};
#      # support merging from existing loadContentCnf already contained in the record data:
#      $loadCfg = $self->json->decode($record->{loadContentCnf}) if (defined $record->{loadContentCnf});
#      
#      %{ $loadCfg } = (
#        %{ $self->get_record_loadContentCnf($record) },
#        %{ $loadCfg }
#      );
#      
#      $loadCfg->{autoLoad} = {} unless (defined $loadCfg->{autoLoad});
#      $loadCfg->{autoLoad}->{url} = $self->Module('item')->base_url unless (defined $loadCfg->{autoLoad}->{url});
#      
#      
#      $record->{loadContentCnf} = $self->json->encode($loadCfg);
#    }
#  }
#
#  return $result;
#};

sub options_menu_button_Id {
  my $self = shift;
  return $self->instance_id . '-options-menu-btn';
}

sub options_menu_items {
  my $self = shift;
  return undef;
}


sub options_menu {
  my $self = shift;
  
  my $items = $self->options_menu_items or return undef;
  return undef unless (ref($items) eq 'ARRAY') && scalar(@$items);
  
  # Make it easy to find the options menu on the client side (JS):
  my $menu_id = $self->instance_id . '-options-menu';
  $self->apply_extconfig('options_menu_id' => $menu_id );
  
  return {
    xtype    => 'button',
    id      => $self->options_menu_button_Id,
    text    => 'Options',
    iconCls  => 'ra-icon-gears',
    itemId  => 'options-button',
    menu => {
      items => $items,
      id => $menu_id
    }
  };
}



sub tbar_items {
  my $self = shift;
  
  my $arrayref = [];
  
  push @$arrayref, '<img src="' . $self->title_icon_href . '" />'     if (defined $self->title_icon_href);
  push @$arrayref, '<b>' . $self->title . '</b>'                if (defined $self->title);

  my $menu = $self->options_menu;
  push @$arrayref, ' ', '-' if (defined $menu and scalar(@$arrayref) > 0); 
  push @$arrayref, $menu if (defined $menu);
  
  push @$arrayref, '->';
  
  push @$arrayref, $self->add_button if (
    defined $self->add_record_class and
    $self->show_add_button
  );

  return (scalar @$arrayref > 1) ? $arrayref : undef;
}
sub show_add_button { 1 }

sub add_button {
  my $self = shift;
  
  my $loadCfg = {
    url => $self->suburl('add'),
    %{ $self->add_loadContentCnf }
  };
  
  my $handler = RapidApp::JSONFunc->new( raw => 1, func =>
    'function(btn) { btn.ownerCt.ownerCt.loadTargetObj.loadContent(' . $self->json->encode($loadCfg) . '); }'
  );
  
  return RapidApp::JSONFunc->new( func => 'new Ext.Button', parm => {
    handler => $handler,
    %{ $self->add_button_cnf }
  });
}




sub set_all_columns_hidden {
  my $self = shift;
  return $self->apply_to_all_columns(
    hidden => \1
  );
}


sub set_columns_visible {
  my $self = shift;
  my @cols = (ref($_[0]) eq 'ARRAY') ? @{ $_[0] } : @_; # <-- arg as array or arrayref
  return $self->apply_columns_list(\@cols,{
    hidden => \0
  });
}



#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;