package RapidApp::Spreadsheet::ExcelTableReader::RowIter;

use strict;
use warnings;
use Moose;

use Spreadsheet::ParseExcel;
use RapidApp::Spreadsheet::ParseExcelExt;

has 'wsheet'   => ( is => 'ro', isa => 'Spreadsheet::ParseExcel::Worksheet', required => 1 );
has 'fields'   => ( is => 'ro', isa => 'ArrayRef', required => 1 );
has 'rowStart' => ( is => 'ro', isa => 'Int', required => 1 );
has 'rowLimit' => ( is => 'ro', isa => 'Int', required => 1 );
has 'colStart' => ( is => 'ro', isa => 'Int', required => 1 );
has 'colLimit' => ( is => 'ro', isa => 'Int', required => 1 );

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

package RapidApp::Spreadsheet::ExcelTableReader;

use strict;
use warnings;
use Moose;

use Spreadsheet::ParseExcel;
use RapidApp::Spreadsheet::ParseExcelExt;

has 'wsheet'     => ( is => 'ro', isa => 'Spreadsheet::ParseExcel::Worksheet', required => 1 );
has 'fields'     => ( is => 'rw', lazy_build => 1 );
has 'colHeaders' => ( is => 'rw', lazy_build => 1 );
has 'headerRow'  => ( is => 'rw', lazy_build => 1 );
has 'headerCol'  => ( is => 'rw', required => 1, default => 0 );

sub colCount {
	my $self= shift;
	return scalar(@{$self->colHeaders});
}

sub _build_fields {
	my $self= shift;
	$self->has_colHeaders or die "either fields or colHeaders must be specified";
	return [ @{$self->colHeaders} ]; # make a copy
}

sub _build_colHeaders {
	my $self= shift;
	$self->has_fields or die "either fields or colHeaders must be specified";
	return [ @{$self->fields} ]; # make a copy
}

sub _build_headerRow {
	my $self= shift;
	my $row= $self->findHeader or die "Cannot find header row. Expected [".(join '] [',$self->colHeaders)."]";
	return $row;
}

sub findHeader {
	my $self= shift;
	
	defined $self->colHeaders or die "cannot find header until colHeaders are defined";
	
	# find the first row that could be the header
	my ($minRow, $maxRow)= $self->wsheet->row_range();
	my $headerRow= $minRow;
	while ($headerRow <= $maxRow) {
		last if $self->wsheet->cell_text($headerRow, $self->headerCol) eq $self->colHeaders->[0];
		$headerRow++;
	}
	$headerRow <= $maxRow or return undef;
	
	# validate the header row
	for (my $col=0; $col < $self->colCount; $col++) {
		my $hdr= $self->wsheet->cell_text($headerRow, $self->headerCol + $col);
		$hdr eq $self->colHeaders->[$col] or return undef;
	}
	
	return $headerRow == 0? '0 but true' : $headerRow;
}

sub iter {
	my $self= shift;
	my ($minRow, $maxRow)= $self->wsheet->row_range();
	return RapidApp::Spreadsheet::ExcelTableReader::RowIter->new({
		wsheet => $self->wsheet,
		fields => $self->fields,
		rowStart => $self->headerRow+1,
		rowLimit => $maxRow+1,
		colStart => $self->headerCol,
		colLimit => $self->headerCol + $self->colCount
	});
}

sub rowsAsArray {
	my $self= shift;
	my $itr= $self->iter;
	my $result= [];
	while (my $row= $itr->nextRowArray) {
		push @$result, $row;
	}
	return $result;
}

sub rowsAsHash {
	my $self= shift;
	my $itr= $self->iter;
	my $result= [];
	while (my $row= $itr->nextRowHash) {
		push @$result, $row;
	}
	return $result;
}

1;
