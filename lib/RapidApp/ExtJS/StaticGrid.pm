package RapidApp::ExtJS::StaticGrid;
#
# -------------------------------------------------------------- #
#
#   -- Catalyst/Ext-JS Tree
#
#
# 2010-04-21:	Version 0.1 (HV)
#	Initial development


use strict;
use Moose;

extends 'RapidApp::ExtJS::ContainerObject';


our $VERSION = '0.1';

#### --------------------- ####

has 'fields'			=> ( is => 'ro',	required => 1,		isa => 'ArrayRef'	);
has 'data'				=> ( is => 'ro',	required => 1,		isa => 'ArrayRef'	);

has 'xtype'				=> ( is => 'ro',	default => 'grid'							);
has 'id'					=> ( is => 'ro',	default => 'static-grid'				);
has 'stripeRows'		=> ( is => 'ro',	default => sub { \1 }						);
has 'columnLines'		=> ( is => 'ro',	default => sub { \1 }						);

has 'store'				=> ( is => 'ro',	lazy_build => 1							);
has 'store_fields'	=> ( is => 'ro',	lazy_build => 1							);
has 'store_data'		=> ( is => 'ro',	lazy_build => 1							);
has 'columns'			=> ( is => 'ro',	lazy_build => 1							);




sub _build_columns {
	my $self = shift;
	my $a = [];
	
	foreach my $field (@{$self->fields}) {
		my $f = {};
		if (ref($field) eq 'HASH') {
			$f = $field;
		}
		else {
			$f->{name} = $field;
		}
	
		$f->{header} 		= $f->{name} 		unless (defined $f->{header});
		$f->{dataIndex} 	= $f->{name} 		unless (defined $f->{dataIndex});
		$f->{sortable} 	= \1 					unless (defined $f->{sortable});
	
		push @$a, $f;
	}
	return $a;
}



sub _build_store {
	my $self = shift;

	return {
		xtype		=> 'arraystore',
		fields	=> $self->store_fields,
		data		=> $self->store_data
	};
}


sub _build_store_fields {
	my $self = shift;
	my $a = [];
	foreach my $col (@{$self->columns}) {
		push @$a, {name => $col->{dataIndex}};
	}
	return $a;
}


sub _build_store_data {
	my $self = shift;
	my $a = [];
	foreach my $row (@{$self->data}) {
		if (ref($row) eq 'HASH') {
			my $new_row = [];
			foreach my $col (@{$self->columns}) {
				push @$new_row, $row->{$col->{dataIndex}};
			}
			push @$a, $new_row;
		}
		else {
			#$row should be an ArrayRef, but we don't check for it, because we would want it to fail later:
			push @$a, $row;
		}
	}
	return $a;
}




no Moose;
__PACKAGE__->meta->make_immutable;
1;