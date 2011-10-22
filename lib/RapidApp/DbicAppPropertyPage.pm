package RapidApp::DbicAppPropertyPage;
use strict;
use warnings;
use Moose;

extends 'RapidApp::AppDataStore2';
with 'RapidApp::Role::DbicLink2';

use RapidApp::DbicAppPropertyPage1;

# All-purpose record display module. Works great with AppGrid2/DbicLink2 like this:
#
#has 'open_record_class'	=> ( is => 'ro', lazy => 1, default => sub {
#	my $self = shift;
#	{ 
#		class 	=> 'RapidApp::DbicAppPropertyPage',
#		params	=> {
#			ResultSource => $self->ResultSource,
#			record_pk => $self->record_pk
#		}
#	}
#});


use RapidApp::Include qw(sugar perlutil);

has 'ResultSource' => ( is => 'ro', required => 1 );


has '+DataStore_build_params' => ( default => sub {{
	store_autoLoad => 1,
	reload_on_save => 0,
}});


sub BUILD {
	my $self = shift;
	
	
	# WTF!!!!!!!!!! Without this the whole world breaks and I have no idea why
	# FIXME!!!!!
	$self->apply_init_modules( item => { 
		class 	=> 'RapidApp::DbicAppPropertyPage1',
		params	=> { 
			ResultSource => $self->ResultSource, 
			record_pk => $self->record_pk,
		}
	});

	$self->add_ONCONTENT_calls('apply_items_config');
}


sub ResultSet {
	my $self = shift;
	my $Rs = shift;
	
	my $value = $self->c->req->params->{$self->record_pk};
	return $Rs->search_rs($self->record_pk_cond($value));
}


sub apply_items_config {
	my $self = shift;
	
	$self->apply_extconfig( items => [ $self->full_property_grid ] );
}

#has '+dbiclink_updatable' => ( default => 1 );


sub TableSpec_property_grids {
	my $self = shift;
	my $TableSpec = shift;
	
	my %cols = map { $_->{name} => $_ } @{ $self->column_list };
	my @columns = map { $cols{$_} } $TableSpec->local_column_names;
	my $fields = [ grep { not jstrue $_->{no_column} } @columns  ];
	
	my $title = $TableSpec->relspec_prefix;

	my @items = ();
	push @items, $self->property_grid($title,$fields), { xtype => 'spacer', height => 5 } if (@$fields > 0);
	my @TableSpecs = map { $TableSpec->related_TableSpec->{$_} } @{$TableSpec->related_TableSpec_order};
	push @items, $self->TableSpec_property_grids($_) for (@TableSpecs);
	
	return @items;
}



sub full_property_grid {
	my $self = shift;
	
	return $self->TableSpec_property_grids($self->TableSpec);
	
	my $fields = [ grep { not jstrue $_->{no_column} } @{ $self->column_list } ];
	return $self->property_grid('Properties',$fields);
}


sub property_grid {
	my $self = shift;
	my $title = shift;
	my $fields = shift;
	my $opt = shift || {};
	
	$title = $self->TableSpec->name . '.' . $title unless ($title eq '');
	$title = $self->TableSpec->name if ($title eq '');
	
	my $conf = {

		autoWidth		=> \1,
		collapsible => \1,
		collapseFirst => \0,
		titleCollapse => \1,
		autoHeight => \1,
		title => $title,

		xtype => 'apppropertygrid',
		hideHeaders => \1,
		autoHeight => \1,
		editable => \1,
		fields => $fields,
		store => $self->getStore_func,
		nameWidth => 250,
		
		sm => RapidApp::JSONFunc->new( func => 'new Ext.grid.RowSelectionModel', parm => {
			listeners => {
				# Disable row selection (note that disableSelection doesn't work in propertygrid with 'source')
				beforerowselect => RapidApp::JSONFunc->new( raw => 1, func => 'function() { return false; }' )
			}
		}),
		plugins => [ 'titlecollapseplus' ]
	};
	
	return merge($conf,$opt);
}




1;


