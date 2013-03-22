package RapidApp::DbicSchemaGrid;
use strict;
use Moose;
extends 'RapidApp::AppGrid2';

use RapidApp::Include qw(sugar perlutil);

has 'Schema', is => 'ro', isa => 'Object', required => 1;
has '+record_pk', default => 'source';

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
			width => 170
		},
		rows => {
			header => 'Rows',
			width => 80,
			xtype => 'numbercolumn',
			format => '0,0',
			align => 'right',
		}
	);
	
	$self->apply_extconfig(tabTitle => $self->tabTitle);
	$self->apply_extconfig(tabIconCls => $self->tabIconCls) if ($self->tabIconCls);

}


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
		my $class = $self->Schema->class($_);
		my $url = try{$class->TableSpec_get_conf('open_url_multi')};
		
		{
			source => $url ? '<a href="#!' . $url . '">' . $_ . '</a>' : $_,
			rows => $self->Schema->resultset($_)->count
		};
		
	} $self->Schema->sources;
}



#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;