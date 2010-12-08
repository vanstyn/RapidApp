package RapidApp::AppGrid2;


use strict;
use Moose;

extends 'RapidApp::AppCmp';

use RapidApp::Include qw(sugar perlutil);

#use RapidApp::DataStore2;

with 'RapidApp::Role::DataStore2';

use Try::Tiny;

use RapidApp::Column;

has 'record_pk'			=> ( is => 'ro', default => 'id' );
has 'DataStore_class'	=> ( is => 'ro', default => 'RapidApp::DataStore2', isa => 'ClassName' );


has 'title' => ( is => 'ro', default => undef );
has 'title_icon_href' => ( is => 'ro', default => undef );

has 'open_record_class' => ( is => 'ro', default => undef, isa => 'Maybe[ClassName]' );
has 'add_record_class' => ( is => 'ro', default => undef, isa => 'Maybe[ClassName]' );


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


sub BUILD {
	my $self = shift;
	
	$self->apply_config(
		xtype						=> 'appgrid2',
		pageSize					=> 25,
		stripeRows				=> \1,
		columnLines				=> \1,
		use_multifilters		=> \1,
		gridsearch				=> \1,
		gridsearch_remote		=> \1,
		column_allow_save_properties => [ 'width','hidden' ]
	);
	
	# The record_pk is forced to be added/included as a column:
	if (defined $self->record_pk) {
		$self->apply_columns( $self->record_pk => {} );
		push @{ $self->include_columns }, $self->record_pk if (scalar @{ $self->include_columns } > 0);
		#$self->meta->find_attribute_by_name('include_columns_hash')->clear_value($self);
		%{ $self->include_columns_hash } = ();
	}
	
	if (defined $self->open_record_class or defined $self->add_record_class) {
		$self->apply_listeners(
			beforerender => RapidApp::JSONFunc->new( raw => 1, func => 
				'Ext.ux.RapidApp.AppTab.cnt_init_loadTarget' 
			)
		);
	}
	
	if (defined $self->open_record_class) {
		$self->apply_init_modules( item => $self->open_record_class );
		
		$self->apply_listeners(
			rowdblclick => RapidApp::JSONFunc->new( raw => 1, func => 
				'Ext.ux.RapidApp.AppTab.gridrow_nav' 
			)
		);
	}
	
	$self->apply_init_modules( add 	=> $self->add_record_class	) if (defined $self->add_record_class);
	
	$self->apply_actions( save_search => 'save_search' ) if ( $self->can('save_search') );
	$self->apply_actions( delete_search => 'delete_search' ) if ( $self->can('delete_search') );
	
	$self->DataStore->add_read_raw_mungers(RapidApp::Handler->new( scope => $self, method => 'add_loadContentCnf_read_munger' ));
	
	$self->add_ONREQUEST_calls('init_onrequest');
}


sub init_onrequest {
	my $self = shift;
		
	#$self->apply_config(store => $self->JsonStore);
	$self->apply_config(tbar => $self->tbar_items) if (defined $self->tbar_items);
	
	# This is set in ONREQUEST instead of BUILD because it can change depending on the
	# user that is logged in
	if($self->can('action_delete_records') and $self->get_module_option('delete_records')) {
		my $act_name = 'delete_rows';
		$self->apply_actions($act_name => 'action_delete_records' );
		$self->apply_config(delete_url => $self->suburl($act_name));
	}
	
	$self->apply_extconfig( columns => $self->DataStore->column_list );
	
}





sub add_loadContentCnf_read_munger {
	my $self = shift;
	my $result = shift;
	
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
}



=pod
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
=cut


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