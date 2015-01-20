package RapidApp::Spreadsheet::ExcelTableReader;

use strict;
use warnings;
use Moose;

use Spreadsheet::ParseExcel;
use RapidApp::Spreadsheet::ParseExcelExt;
use RapidApp::Spreadsheet::ExcelTableReader::RowIter;

=head1 ExcelTableReader

  $fields= [ 'foo', 'bar', 'baz' ];
  $colHdr= [ 'Foo', 'Bar And Stuff', 'Baz' ];
  $tr= RapidApp::Spreadsheet::ExcelTableReader(
    wsheet     => $ws,
    fields     => $fields,
    fieldLabels => $colHdr,
    headerCol  => 0
  );
  
  #optional
  $tr->findHeader or die "Not a valid Excel file";
  
  for ($i= $tr->itr; $row= $i->nextRowHash; ) {
    print Dumper(%$row);
  }
  
  $allRows_2dArray= $tr->rowsAsArray;
  $allRows_hashes= $tr->rowsAsHash;

ExcelTableReader simply takes a list of columns and looks for a row containing them in the Excel
file.  It then lets you iterate through the document pulling those columns into either a hash or
an array.  There are separate "fields" and "fieldLabels" properties in order to let you search for
one string in the Excel file and associate it with a different name in the returned hash.

=head2 wsheet

wsheet is the worksheet object returned from Spreadsheet::PArseExcel.  All values returned by
TableReader come from reading cells in the worksheet.

=cut

has 'wsheet'     => ( is => 'ro', isa => 'Spreadsheet::ParseExcel::Worksheet', required => 1 );

=head2 fields

Fields specifies the official name of the data being extracted form a column.  This name will be
used as keys when returning row data as a hash.  If you are only using array methods and specify
the header row, this is ignored.

=cut

has 'fields'     => ( is => 'rw', lazy_build => 1 );

=head2 fieldLabels
=head2 colHeaders

FieldLabels specifies the names to look for in the header row.  If fieldLabels is not specified,
it will default to the same as the name of the field.

=cut

has 'fieldLabels' => ( is => 'rw', lazy_build => 1 );
sub colHeaders { (shift)->fieldLabels(@_); }

=head2 headerCol

Required.  Specifies the 0-based column in the excel file to search for the leftmost header,
if a search is required.  Else, it simply is the Y coordinate of the first header cell.

=cut

has 'headerCol'  => ( is => 'rw', required => 1, default => 0 );

=head2 headerRow

Optional.  Specifies the 0-based row in the excel file to search for the leftmost header.
If not specified, the TableReader will search the worksheet form top to bottom looking for
a row that matches the fieldLabels.

If specified directly, no search will be performed, and the header is assumed to exist at this row.
(no check is performed either).  It is possible to specify -1 if the data begins on row 0.

=cut

has 'headerRow'  => ( is => 'rw', lazy_build => 1 );

sub colCount {
	my $self= shift;
	return scalar(@{$self->fieldLabels});
}

sub _build_fields {
	my $self= shift;
	$self->has_fieldLabels or die "either fields or fieldLabels must be specified";
	return [ @{$self->fieldLabels} ]; # make a copy
}

sub _build_fieldLabels {
	my $self= shift;
	$self->has_fields or die "either fields or fieldLabels must be specified";
	return [ @{$self->fields} ]; # make a copy
}

sub _build_headerRow {
	my $self= shift;
	my $row= $self->findHeader or die "Cannot find header row. Expected [".(join '] [',$self->fieldLabels)."]";
	return $row;
}

=head2 findHeader

Searches the excel worksheet top to bottom looking for the header row.  Returns a row index
(0-based, always true) if found, and undef of not found.  Only the "headerCol" column is searched
for the leftmost column (i.e. it never searches sideways), and all columns must match.
There is no "near match which generates a warning" feature, though that might be nice.

=cut

sub findHeader {
	my $self= shift;
	
	defined $self->fieldLabels or die "cannot find header until fieldLabels are defined";
	
	# find the first row that could be the header
	my ($minRow, $maxRow)= $self->wsheet->row_range();
	my $headerRow= $minRow;
	while ($headerRow <= $maxRow) {
		last if $self->wsheet->cell_text($headerRow, $self->headerCol) eq $self->fieldLabels->[0];
		$headerRow++;
	}
	$headerRow <= $maxRow or return undef;
	
	# validate the header row
	for (my $col=0; $col < $self->colCount; $col++) {
		my $hdr= $self->wsheet->cell_text($headerRow, $self->headerCol + $col);
		$hdr eq $self->fieldLabels->[$col] or return undef;
	}
	
	return $headerRow == 0? '0 but true' : $headerRow;
}

=head2 iter

Creates an iterator object to help iterate through the rows.

=cut

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


=head2 rowsAsHash

  $tr= RapidApp::Spreadsheet::ExcelTableReader(
    wsheet     => $ws,
    fields     => $fields,
    headerCol  => 0
  );
  $allRows_hashes= $tr->rowsAsHash;

Returns all the rows of the Excel file in an array, each represented as an array of values in column order.

=cut

sub rowsAsArray {
	my $self= shift;
	my $itr= $self->iter;
	my $result= [];
	while (my $row= $itr->nextRowArray) {
		push @$result, $row;
	}
	return $result;
}

=head2 rowsAsHash

  $tr= RapidApp::Spreadsheet::ExcelTableReader(
    wsheet     => $ws,
    fields     => $fields,
    headerCol  => 0
  );
  $allRows_hashes= $tr->rowsAsHash;

Returns all the rows of the Excel file in an array, each represented as a hash of fieldname to value.

=cut

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
