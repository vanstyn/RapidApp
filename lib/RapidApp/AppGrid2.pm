package RapidApp::AppGrid2;


use strict;
use Moose;

extends 'RapidApp::AppCnt';
with 'RapidApp::Role::DataStore';

use Try::Tiny;

use RapidApp::Column;

use RapidApp::JSONFunc;
#use RapidApp::AppDataView::Store;

use Term::ANSIColor qw(:constants);

use RapidApp::MooseX::ClassAttrSugar;
setup_apply_methods_for('config');
setup_apply_methods_for('listeners');

apply_default_config(
	xtype						=> 'appgrid2',
	pageSize					=> 25,
	stripeRows				=> \1,
	columnLines				=> \1,
	use_multifilters		=> \1,
	gridsearch				=> \1,
	gridsearch_remote		=> \1,
	column_allow_save_properties => [ 'width','hidden' ]
);




has 'columns' => ( is => 'rw', default => sub {{}}, isa => 'HashRef', traits => ['RapidApp::Role::PerRequestBuildDefReset'] );
has 'column_order' => ( is => 'rw', default => sub {[]}, isa => 'ArrayRef', traits => ['RapidApp::Role::PerRequestBuildDefReset'] );
has 'title' => ( is => 'ro', default => undef );
has 'title_icon_href' => ( is => 'ro', default => undef );

has 'open_record_class' => ( is => 'ro', default => undef );
has 'add_record_class' => ( is => 'ro', default => undef );

has 'include_columns' => ( is => 'ro', default => sub {[]} );
has 'exclude_columns' => ( is => 'ro', default => sub {[]} );

# autoLoad needs to be false for the paging toolbar to not load the whole
# data set
has 'store_autoLoad' => ( is => 'ro', default => sub {\0} );

has 'add_loadContentCnf' => ( is => 'ro', default => sub {
	{
		title		=> 'Add',
		iconCls	=> 'icon-add'
	}
});

has 'add_button_cnf' => ( is => 'ro', default => sub {
	{
		text		=> 'Add',
		iconCls	=> 'icon-add'
	}
});


# get_record_loadContentCnf is used on a per-row basis to set the 
# options used to load the row in a tab when double-clicked
# This should be overridden in the subclass:
sub get_record_loadContentCnf {
	my ($self, $record) = @_;
	
	return {
		title	=> $self->record_pk . ': ' . $record->{$self->record_pk}
	};
}



sub run_load_saved_search {
	my $self = shift;
	
	return unless ($self->can('load_saved_search'));
	
	#return $self->load_saved_search;
	
	
	try {
		$self->load_saved_search;
	}
	catch {
		my $err = $_;
		$self->set_response_warning({
			title	=> 'Error loading search',
			msg	=> 'An error occured while trying to load the saved search'
		});
		
		#die $err;
	
	};
	
	
}






after 'ONREQUEST' => sub {
	my $self = shift;
	
	$self->run_load_saved_search;
	
	$self->apply_config(store => $self->JsonStore);
	$self->apply_config(tbar => $self->tbar_items) if (defined $self->tbar_items);
	
	# This is set in ONREQUEST instead of BUILD because it can change depending on the
	# user that is logged in
	if($self->can('action_delete_records') and $self->get_module_option('delete_records')) {
		my $act_name = 'delete_rows';
		$self->apply_actions($act_name => 'action_delete_records' );
		$self->apply_config(delete_url => $self->suburl($act_name));
	}
	
};


sub BUILD {
	my $self = shift;
	
	# The record_pk is forced to be added/included as a column:
	if (defined $self->record_pk) {
		$self->apply_columns( $self->record_pk => {} );
		push @{ $self->include_columns }, $self->record_pk if (scalar @{ $self->include_columns } > 0);
		$self->meta->find_attribute_by_name('include_columns_hash')->clear_value($self);
	}
	
	if (defined $self->open_record_class or defined $self->add_record_class) {
		$self->apply_listeners(
			beforerender => RapidApp::JSONFunc->new( raw => 1, func => 
				'Ext.ux.RapidApp.AppTab.cnt_init_loadTarget' 
			)
		);
	}
	
	if (defined $self->open_record_class) {
		$self->apply_modules( item => $self->open_record_class );
		
		$self->apply_listeners(
			rowdblclick => RapidApp::JSONFunc->new( raw => 1, func => 
				'Ext.ux.RapidApp.AppTab.gridrow_nav' 
			)
		);
	}
	
	$self->apply_modules( add 	=> $self->add_record_class	) if (defined $self->add_record_class);
	
	
	$self->apply_actions( save_search => 'save_search' ) if ( $self->can('save_search') );
	$self->apply_actions( delete_search => 'delete_search' ) if ( $self->can('delete_search') );
	
}



around 'store_read_raw' => sub {
	my $orig = shift;
	my $self = shift;
	
	my $result = $self->$orig(@_);
	
	# Add a 'loadContentCnf' field to store if open_record_class is defined.
	# This data is used when a row is double clicked on to open the open_record_class
	# module in the loadContent handler (JS side object). This is currently AppTab
	# but could be other JS classes that support the same API
	if (defined $self->open_record_class) {
		foreach my $record (@{$result->{rows}}) {
			my $loadCfg = {};
			# support merging from existing loadContentCnf already contained in the record data:
			$loadCfg = $self->json->decode($record->{loadContentCnf}) if (defined $record->{loadContentCnf});
			
			%{ $loadCfg } = (
				%{ $self->get_record_loadContentCnf($record) },
				%{ $loadCfg }
			);
			
			$loadCfg->{autoLoad} = {} unless (defined $loadCfg->{autoLoad});
			$loadCfg->{autoLoad}->{url} = $self->Module('item')->base_url unless (defined $loadCfg->{autoLoad}->{url});
			
			
			$record->{loadContentCnf} = $self->json->encode($loadCfg);
		}
	}

	return $result;
};





has 'include_columns_hash' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my $hash = {};
	foreach my $col (@{$self->include_columns}) {
		$hash->{$col} = 1;
	}
	return $hash;
});

has 'exclude_columns_hash' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my $hash = {};
	foreach my $col (@{$self->exclude_columns}) {
		$hash->{$col} = 1;
	}
	return $hash;
});




sub options_menu_items {
	my $self = shift;
	return undef;
}


sub options_menu {
	my $self = shift;
	
	my $items = $self->options_menu_items or return undef;
	return undef unless (ref($items) eq 'ARRAY');
	
	return {
		xtype		=> 'button',
		text		=> 'Options',
		iconCls	=> 'icon-gears',
		menu => {
			items	=> $items
		}
	};
}



sub tbar_items {
	my $self = shift;
	
	my $arrayref = [];
	
	push @{$arrayref}, '<img src="' . $self->title_icon_href . '" />' 		if (defined $self->title_icon_href);
	push @{$arrayref}, '<b>' . $self->title . '</b>'								if (defined $self->title);

	my $menu = $self->options_menu;
	push @{$arrayref}, ' ', '-',$menu if (defined $menu); 
	
	push @{$arrayref}, '->';
	
	push @{$arrayref}, $self->add_button if (defined $self->add_record_class);

	return (scalar @{$arrayref} > 1) ? $arrayref : undef;
}

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


sub apply_columns {
	my $self = shift;
	my %column = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $name (keys %column) {
	
		next unless ($self->valid_colname($name));
	
		unless (defined $self->columns->{$name}) {
			$self->columns->{$name} = RapidApp::Column->new( name => $name );
			push @{ $self->column_order }, $name;
		}
		
		$self->columns->{$name}->apply_attributes(%{$column{$name}});
	}
	
	return $self->apply_config(columns => $self->column_list);
}



#sub add_column {
#	my $self = shift;
#	my %column = @_;
#	%column = %{$_[0]} if (ref($_[0]) eq 'HASH');
#	
#	foreach my $name (keys %column) {
#		if (defined $self->columns->{$name}) {
#			$self->columns->{$name}->apply_attributes(%{$column{$name}});
#		}
#		else {
#			$self->columns->{$name} = RapidApp::Column->new(%{$column{$name}}, name => $name );
#			push @{ $self->column_order }, $name;
#		}
#
#	}
#}


sub column_list {
	my $self = shift;
	
	my @list = ();
	foreach my $name (@{ $self->column_order }) {
		push @list, $self->columns->{$name}->get_grid_config;
	}
	
	return \@list;
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


sub apply_to_all_columns {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $column (keys %{ $self->columns } ) {
		$self->columns->{$column}->apply_attributes(%opt);
	}
	
	return $self->apply_config(columns => $self->column_list);
}

sub apply_columns_list {
	my $self = shift;
	my $cols = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	die "type of arg 1 must be ArrayRef" unless (ref($cols) eq 'ARRAY');
	
	foreach my $column (@$cols) {
		$self->columns->{$column}->apply_attributes(%opt);
	}
	
	return $self->apply_config(columns => $self->column_list);
}


sub set_sort {
	my $self = shift;
	my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	return $self->apply_config( sort => { %opt } );
}


sub batch_apply_opts {
	my $self = shift;
	my %opts = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $opt (keys %opts) {
		if ($opt eq 'columns') {				$self->apply_columns($opts{$opt});				}
		elsif ($opt eq 'column_order') {		$self->set_columns_order(0,$opts{$opt});		}
		elsif ($opt eq 'sort') {				$self->set_sort($opts{$opt});						}
		elsif ($opt eq 'filterdata') {		$self->apply_store_config($opt => $opts{$opt});		}
		else { die "invalid option '$opt' passed to batch_apply_opts";							}
	}
}





sub valid_colname {
	my $self = shift;
	my $name = shift;
	
	if (scalar @{$self->exclude_columns} > 0) {
		return 0 if (defined $self->exclude_columns_hash->{$name});
	}
	
	if (scalar @{$self->include_columns} > 0) {
		return 0 unless (defined $self->include_columns_hash->{$name});
	}
	
	return 1;
}



sub set_columns_order {
	my $self = shift;
	my $offset = shift;
	my @cols = (ref($_[0]) eq 'ARRAY' and not defined $_[1]) ? @{ $_[0] } : @_; # <-- arg as list or arrayref
	
	my %cols_hash = ();
	foreach my $col (@cols) {
		die $col . " specified more than once" if ($cols_hash{$col}++);
	}
	
	my @pruned = ();
	foreach my $col (@{ $self->column_order }) {
		if ($cols_hash{$col}) {
			delete $cols_hash{$col};
		}
		else {
			push @pruned, $col;
		}
	}
	
	my @remaining = keys %cols_hash;
	if(@remaining > 0) {
		die "can't set the order of columns that do not already exist (" . join(',',@remaining) . ')';
	}
	
	splice(@pruned,$offset,0,@cols);
	
	@{ $self->column_order } = @pruned;
	
	return $self->apply_config(columns => $self->column_list);
}







#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;