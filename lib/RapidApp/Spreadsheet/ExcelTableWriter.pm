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
has 'widest' => ( is => 'rw', default => 0 );

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

package RapidApp::Spreadsheet::ExcelTableWriter;

use strict;
use warnings;
use Moose;

use Spreadsheet::ParseExcel;
use RapidApp::Spreadsheet::ParseExcelExt;

has 'wbook'    => ( is => 'ro', isa => 'Spreadsheet::WriteExcel::Workbook', required => 1 );
has 'wsheet'   => ( is => 'ro', isa => 'Spreadsheet::WriteExcel::Worksheet', required => 1 );
has 'columns'  => ( is => 'rw', isa => 'ArrayRef', required => 1 );
has 'rowStart' => ( is => 'rw', isa => 'Int', required => 1, default => 0 );
has 'colStart' => ( is => 'rw', isa => 'Int', required => 1, default => 0 );
has 'headerFormat' => ( is => 'rw', lazy_build => 1 );

sub _build_headerFormat {
	my $self= shift;
	return $self->wbook->add_format(bold => 1, bottom => 1);
}

sub colCount {
	my $self= shift;
	return scalar(@{$self->columns});
}

sub BUILD {
	my $self= shift;
	
	for (my $i= 0; $i < scalar(@{$self->columns}); $i++) {
		my $val= $self->columns->[$i];
		# convert hashes into the proper object
		ref $val eq 'HASH' and
			$self->columns->[$i]= RapidApp::Spreadsheet::ExcelTableWriter::ColDef->new($val);
		# convert scalars into names (and labels)
		ref $val eq '' and
			$self->columns->[$i]= RapidApp::Spreadsheet::ExcelTableWriter::ColDef->new(name => $val);
	}
}

sub curRow {
	my $self= shift;
	defined $self->{_curRow} and return $self->{_curRow};
	return $self->{_curRow}= $self->rowStart;
}

has '_documentStarted' => ( is => 'rw' );
has '_dataStarted' => ( is => 'rw' );

sub excelColIdxToLetter($) {
	my $self= shift;
	my $colNum= shift;
	my $colName= '';
	{
		use integer;
		while ($colNum > 0) {
			$colName.= chr(($colNum % 26) + 65);
			$colNum/= 26;
		}
	}
	length($colName) == 0 and $colName= 'A';
	return $colName;
}

sub _applyColumnFormats {
	my $self= shift;
	
	for (my $i=0; $i < $self->colCount; $i++) {
		my $fmt= $self->columns->[$i]->format;
		my $wid= $self->columns->[$i]->width eq 'auto'? undef : $self->columns->[$i]->width;
		my $xls_col= $self->colStart+$i;
		$self->wsheet->set_column($xls_col, $xls_col, $wid, $fmt);
	}
}

sub prepareDocument {
	my $self= shift;
	!$self->_documentStarted or die 'column formats can only be applied before the first "write"';
	
	$self->_applyColumnFormats();
	$self->_documentStarted(1);
}

sub writePreamble {
	my $self= shift;
	!$self->_dataStarted or die 'Preamble must come before headers and data';
	
	$self->_documentStarted or $self->prepareDocument;
	$self->wsheet->write_row($self->curRow, $self->colStart, \@_);
	$self->{_curRow}++;
}

sub writeHeaders {
	my $self= shift;
	!$self->_dataStarted or die 'Headers cannot be written twice';
	
	$self->_documentStarted or $self->prepareDocument;
	for (my $i=0; $i < $self->colCount; $i++) {
		$self->wsheet->write_string($self->curRow, $self->colStart + $i, $self->columns->[$i]->label, $self->headerFormat);
		$self->columns->[$i]->updateWidest(length($self->columns->[$i]->label)*1.2);
	}
	$self->_dataStarted(1);
	$self->{_curRow}++;
}

sub writeRow {
	my $self= shift;
	my $rowData;
	if (ref $_[0] eq 'ARRAY') {
		$rowData= $_[0];
	} elsif (ref $_[0] eq 'HASH') {
		$rowData= $self->rowHashToArray($_[0]);
	} else {
		$rowData= [ @_ ];
	}
	
	$self->_dataStarted or $self->writeHeaders;
	
	for (my $i=0; $i < $self->colCount; $i++) {
		if ($self->columns->[$i]->isString) {
			$self->wsheet->write_string($self->curRow, $self->colStart + $i, $rowData->[$i]);
		} else {
			$self->wsheet->write($self->curRow, $self->colStart + $i, $rowData->[$i]);
		}
		$self->columns->[$i]->updateWidest(length $rowData->[$i]) if (defined $rowData->[$i]);
	}
	$self->{_curRow}++;
}

sub autosizeColumns {
	my $self= shift;
	for (my $i=0; $i < $self->colCount; $i++) {
		if ($self->columns->[$i]->width eq 'auto') {
			my $xls_col= $self->colStart + $i;
			$self->wsheet->set_column($xls_col, $xls_col, $self->columns->[$i]->widest+.5);
		}
	}
}

1;