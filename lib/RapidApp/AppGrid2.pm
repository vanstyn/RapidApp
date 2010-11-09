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
setup_add_methods_for('config');
setup_add_methods_for('listeners');




add_default_config(
	xtype			=> 'appgrid2',
	pageSize		=> 25

);

has 'columns' => ( is => 'rw', default => sub {{}} );
has 'column_order' => ( is => 'rw', default => sub {[]} );


# autoLoad needs to be false for the paging toolbar to not load the whole
# data set
has 'store_autoLoad' => ( is => 'ro', default => sub {\0} );

before 'content' => sub {
	my $self = shift;
	
	$self->add_config(store => $self->JsonStore);
	#$self->add_config(columns => $self->grid_columns) if ($self->can('grid_columns'));
	$self->add_config(columns => $self->column_list);



	use Data::Dumper;
	#print STDERR CYAN . Dumper($self->config) . CLEAR;

};


#sub add_column {
#	my $self = shift;
#	my %column = @_;
#	%column = %{$_[0]} if (ref($_[0]) eq 'HASH');
#	
#	foreach my $name (keys %column) {
#		unless (defined $self->columns->{$name}) {
#			$self->columns->{$name} = {};
#			push @{ $self->column_order }, $name;
#		}
#		
#		%{ $self->columns->{$name} } = (
#			%{ $self->columns->{$name} },
#			%{ $column{$name} }
#		);
#	}
#}



sub add_column {
	my $self = shift;
	my %column = @_;
	%column = %{$_[0]} if (ref($_[0]) eq 'HASH');
	
	foreach my $name (keys %column) {
		if (defined $self->columns->{$name}) {
			$self->columns->{$name}->apply_attributes(%{$column{$name}});
		}
		else {
			$self->columns->{$name} = RapidApp::Column->new(%{$column{$name}}, name => $name );
			push @{ $self->column_order }, $name;
		}

	}
}


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
	
	foreach my $column (keys %{ $self->columns } ) {
		$self->columns->{$column}->hidden(\1);
	}
}


sub set_columns_visible {
	my $self = shift;
	my @cols = @_;
	@cols = @{ $_[0] } if (ref($_[0]) eq 'ARRAY');
	
	foreach my $column (@cols) {
		$self->columns->{$column}->hidden(\0);
	}
}








#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;