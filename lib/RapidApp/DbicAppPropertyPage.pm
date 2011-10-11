package RapidApp::DbicAppPropertyPage;
use strict;
use warnings;
use Moose;
extends 'RapidApp::AppCmp';
with 'RapidApp::Role::DataStore2';
with 'RapidApp::Role::DbicLink';

# All-purpose record display module. Works great with DbicAppGrid2 like this:
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

	$self->add_ONCONTENT_calls('apply_items_config');
}


sub apply_items_config {
	my $self = shift;
	
	$self->apply_extconfig( items => [ $self->full_property_grid ] );
}

has '+dbiclink_updatable' => ( default => 1 );

sub read_extra_search_set {
	my $self = shift;
	return [ 'me.' . $self->record_pk => $self->c->req->params->{$self->record_pk} ];
}

sub full_property_grid {
	my $self = shift;
	
	
	
	my $fields = [ grep { not jstrue $_->{no_column} } @{ $self->column_list } ];
	
	return $self->property_grid('Properties',$fields);
	
	my @items = ();
	
	my $name = $self->ResultSource->source_name;
	my $hash = $self->ResultSource->schema->class($name)->TableSpec_rel_columns;
	
	my $relcols = {};
	foreach my $rel (keys %$hash) {
		my %map = map {$_ => 1} @{ $hash->{$rel} };
		my @f = grep { $map{$_->{name}} } @$fields;
		$relcols = { %$relcols, map {$_ => 1} @f };
		push @items, { xtype => 'spacer', height => 5 }, $self->property_grid($rel,\@f) if (scalar @f > 0);
	}
	
	my @base = grep { not $relcols->{$_} } @$fields;
	return $self->property_grid('object',\@base), @items;
}


sub property_grid {
	my $self = shift;
	my $title = shift;
	my $fields = shift;
	
	return {
		xtype => 'panel',
		autoWidth		=> \1,
		collapsible => \1,
		collapseFirst => \1,
		titleCollapse => \1,
		autoHeight => \1,
		title => $title,
		items => {
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
			})
			
			
			# preliminary feature: only these columns will be editable
			#editable_fields => { map {$_ => 1} ( 'name','creator','updater' ) }
		},
	};
}




1;


