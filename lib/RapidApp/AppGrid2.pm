package RapidApp::AppGrid2;


use strict;
use Moose;

extends 'RapidApp::AppCnt';
with 'RapidApp::Role::DataStore';

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
	gridsearch_remote		=> \1
);

has 'columns' => ( is => 'rw', default => sub {{}} );
has 'column_order' => ( is => 'rw', default => sub {[]} );
has 'title' => ( is => 'ro', default => undef );
has 'title_icon_href' => ( is => 'ro', default => undef );

has 'open_record_class' => ( is => 'ro', default => undef );
has 'add_record_class' => ( is => 'ro', default => undef );

has 'include_columns' => ( is => 'ro', default => sub {[]} );
has 'exclude_columns' => ( is => 'ro', default => sub {[]} );

# autoLoad needs to be false for the paging toolbar to not load the whole
# data set
has 'store_autoLoad' => ( is => 'ro', default => sub {\0} );

before 'content' => sub {
	my $self = shift;
	
	$self->apply_config(store => $self->JsonStore);
	$self->apply_config(columns => $self->column_list);
	$self->apply_config(tbar => $self->tbar_items) if (defined $self->tbar_items);

};


sub BUILD {
	my $self = shift;
	
	# The record_pk is forced to be added/included as a column:
	if (defined $self->record_pk) {
		$self->apply_columns( $self->record_pk => {} );
		push @{ $self->include_columns }, $self->record_pk if (scalar @{ $self->include_columns } > 0);
		$self->meta->find_attribute_by_name('include_columns_hash')->clear_value($self);
	}
	
	if (defined $self->open_record_class) {
		$self->apply_modules( item => $self->open_record_class	);
		
		$self->apply_listeners(
			beforerender => RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppTab.cnt_init_loadTarget' ),
			rowdblclick => RapidApp::JSONFunc->new( raw => 1, func => 'Ext.ux.RapidApp.AppTab.gridrow_nav' )
		);
	
	}
	
	
	$self->apply_modules( add 	=> $self->add_record_class	) if (defined $self->add_record_class);
}





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





sub tbar_items {
	my $self = shift;
	
	my $arrayref = [];
	
	push @{$arrayref}, '<img src="' . $self->title_icon_href . '" />' 		if (defined $self->title_icon_href);
	push @{$arrayref}, '<b>' . $self->title . '</b>'								if (defined $self->title);

	return undef unless (scalar @{$arrayref} > 0);

	push @{$arrayref}, '->';

	return $arrayref;
}




sub apply_columns {
	my $self = shift;
	my %column = @_;
	%column = %{$_[0]} if (ref($_[0]) eq 'HASH');
	
	foreach my $name (keys %column) {
	
		next unless ($self->valid_colname($name));
	
		unless (defined $self->columns->{$name}) {
			$self->columns->{$name} = RapidApp::Column->new( name => $name );
			push @{ $self->column_order }, $name;
		}
		
		$self->columns->{$name}->apply_attributes(%{$column{$name}});
	}
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
	my @cols = @_;
	@cols = @{ $_[0] } if (ref($_[0]) eq 'ARRAY');
	return $self->apply_columns_list(\@cols,{
		hidden => \0
	});
}


sub apply_to_all_columns {
	my $self = shift;
	my %opt = @_;
	%opt = %{$_[0]} if (ref($_[0]) eq 'HASH');
	
	foreach my $column (keys %{ $self->columns } ) {
		$self->columns->{$column}->apply_attributes(%opt);
	}
}

sub apply_columns_list {
	my $self = shift;
	my $cols = shift;
	my %opt = @_;
	%opt = %{$_[0]} if (ref($_[0]) eq 'HASH');
	
	die "type of arg 1 must be ArrayRef" unless (ref($cols) eq 'ARRAY');
	
	foreach my $column (@$cols) {
		$self->columns->{$column}->apply_attributes(%opt);
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





#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;