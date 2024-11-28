package RapidApp::Spreadsheet::ExcelTableWriter::ColDef;

use Moo;
use namespace::clean;

our %col_type= map +($_ => $_), qw( auto text number date time datetime formula );
sub _check_col_type { exists $col_type{$_[0]} or die "type must be one of ".join(', ', keys %col_type) }

has name       => ( is => 'rw', lazy => 1, builder => 1, predicate => 1 );
has label      => ( is => 'rw', lazy => 1, builder => 1, predicate => 1 );
has type       => ( is => 'rw', isa => \&_check_col_type, default => 'auto' );
has 'format'   => ( is => 'rw' );

# widths are given in Excel width units
# one unit is the width of the average character in Arial 10pt
has width      => ( is => 'rw', required => 1, default => 'auto' );
# widest is updated as data is written
has widest     => ( is => 'rw', default => 2 );
# format_obj is built once the workbook is known
has _format_obj => ( is => 'lazy' );

# For back-compat with earlier versions
sub isString {
  $_[0]->type($_[1]? 'text' : 'auto') if @_ > 1;
  return $_[0]->type eq 'text'
}

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
