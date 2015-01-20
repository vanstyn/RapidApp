package RapidApp::Spreadsheet::ExcelTableReader::RowIter;

use strict;
use warnings;
use Moose;

use Spreadsheet::ParseExcel;
use RapidApp::Spreadsheet::ParseExcelExt;

=head1 RowIter

  $tr= RapidApp::Spreadsheet::ExcelTableReader(...);
  $i= $tr->iter;
  
  while (my $vals= $i->nextRowArray) {
    ...
  }
  $i->rewind;
  while (my $vals= $i->nextRowHash) {
    ...
  }

This class is an iterator that walks down the rows of an excel file.  It is intended to be created
by ExcelTableReader.  It access the spreadsheet object of the parent for all its data, and extracts
values using "->cell_text(y,x)", which has an interface of returning an empty string for
undefined table cells.

=cut

has 'wsheet'   => ( is => 'ro', isa => 'Spreadsheet::ParseExcel::Worksheet', required => 1 );
has 'fields'   => ( is => 'ro', isa => 'ArrayRef', required => 1 );
has 'rowStart' => ( is => 'ro', isa => 'Int', required => 1 );
has 'rowLimit' => ( is => 'ro', isa => 'Int', required => 1 );
has 'colStart' => ( is => 'ro', isa => 'Int', required => 1 );
has 'colLimit' => ( is => 'ro', isa => 'Int', required => 1 );

sub hasNext {
	my $self= shift;
	return $self->{_row} < $self->rowLimit;
}

sub nextRowArray {
	my $self= shift;
	if (defined $self->{_row}) {
		$self->{_row}++;
	} else {
		$self->rewind;
	}
	
	my $row= [];
	my $rowIdx= $self->{_row};
	$rowIdx < $self->rowLimit or return undef;
	for (my $x= $self->colStart; $x < $self->colLimit; $x++) {
		push @$row, $self->wsheet->cell_text($rowIdx, $x);
	}
	return $row;
}

sub nextRowHash {
	my $self= shift;
	if (defined $self->{_row}) {
		$self->{_row}++;
	} else {
		$self->rewind;
	}
	
	my $row= {};
	my $rowIdx= $self->{_row};
	$rowIdx <= $self->rowLimit or return undef;
	for (my $x= $self->colStart; $x < $self->colLimit; $x++) {
		$row->{$self->fields->[$x - $self->colStart]}= $self->wsheet->cell_text($rowIdx, $x);
	}
	return $row;
}

sub rewind {
	my $self= shift;
	$self->{_row}= $self->rowStart;
	return 1;
}

1;
