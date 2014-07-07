package RapidApp::DbicSchemaGrid;
use strict;
use Moose;
extends 'RapidApp::AppGrid2';

use RapidApp::Include qw(sugar perlutil);

has '+auto_autosize_columns', default => 1; #<-- not working

has 'Schema', is => 'ro', isa => 'Object', required => 1;
has '+record_pk', default => 'source';
has 'exclude_sources', is => 'ro', isa => 'ArrayRef', default => sub {[]};

has 'tabTitle', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return (ref $self->Schema);
};

has 'tabIconCls', is => 'ro', lazy => 1, default => undef;

sub BUILD {
	my $self = shift;
	
	$self->apply_columns( 
		source => {
			header => 'Source',
			width => 180
		},
		table => {
			header => 'Table Name',
			width => 150,
			hidden => \1
		},
		class => {
			header => 'Class Name',
			width => 210,
			hidden => \1
		},
		columns => {
			header => 'Columns',
			width => 100,
			xtype => 'numbercolumn',
			format => '0',
			align => 'right',
		},
		rows => {
			header => 'Rows',
			width => 90,
			xtype => 'numbercolumn',
			format => '0,0',
			align => 'right',
		}
	);
	
	$self->set_columns_order(0,qw(source table class columns rows));
	
	$self->apply_extconfig(
		tabTitle => $self->tabTitle,
		use_multifilters => \0,
		pageSize => undef
	);
	
	$self->apply_extconfig(tabIconCls => $self->tabIconCls) if ($self->tabIconCls);
}

has '+DataStore_build_params', default => sub {{
	preload_data => 1,
	store_fields => [
		{ name => 'source' },
		{ name => 'table' },
		{ name => 'class' },
		{ name => 'columns', sortType => 'asInt', type => 'int' },
		{ name => 'rows', sortType => 'asInt', type => 'int' }
	]
}};


sub read_records {
	my $self = shift;
	
	my @rows = $self->schema_source_rows;
	
	return { 
		results => (scalar @rows),
		rows => \@rows 
	};
}


sub schema_source_rows {
	my $self = shift;
	return map {
		my $Source = $self->Schema->source($_);
		my $class = $self->Schema->class($_);
		my $url = try{$class->TableSpec_get_conf('open_url_multi')};
    my $table = $class->table;
		$table = (split(/\./,$table,2))[1] || $table; #<-- get 'table' for both 'db.table' and 'table' format
		
		{
			source => $url ? '<a href="#!' . $url . '">' . $_ . '</a>' : $_,
			table => $table,
			class => $class,
			columns => (scalar $Source->columns),
			rows => $Source->resultset->count
		};
		
	} $self->sources;
}


sub sources {
  my $self = shift;
  my %excl_sources = map {$_=>1} @{$self->exclude_sources};
  return grep { ! $excl_sources{$_} } $self->Schema->sources;
}


#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;