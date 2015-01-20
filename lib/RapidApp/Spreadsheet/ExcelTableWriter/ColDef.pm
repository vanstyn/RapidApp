package RapidApp::Spreadsheet::ExcelTableWriter::ColDef;

use strict;
use warnings;
use Moose;

has 'name'     => ( is => 'rw', lazy_build => 1 );
has 'label'    => ( is => 'rw', lazy_build => 1 );
has 'isString' => ( is => 'rw', required => 1, default => 1 );
has 'format'   => ( is => 'rw' );

# widths are given in Excel width units
# one unit is the width of the average character in Arial 10pt
has 'width'  => ( is => 'rw', required => 1, default => 'auto' );
has 'widest' => ( is => 'rw', default => 2 );

sub _build_label {
	my $self= shift;
	$self->has_name or die "Either field or label must be specified";
	return $self->name;
}

sub _build_name {
	my $self= shift;
	$self->has_label or die "Either field or label must be specified";
	return $self->label;
}

sub updateWidest {
	my $self= shift;
	my $newWidth= shift;
	$self->widest >= $newWidth or $self->widest($newWidth);
}

1;
