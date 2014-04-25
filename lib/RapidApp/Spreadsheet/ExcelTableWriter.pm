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

package RapidApp::Spreadsheet::ExcelTableWriter;

=head1 ExcelTableWriter

Convenience object for writing a table into an Excel worksheet.

ExcelTableWriter does not manage the excel file, and instead takes parameters of the
workbook and worksheet objects to use.  This allows quite a bit of flexibility.

  my $xls= Excel::Writer::XLSX->new($fh);
  
  my $tw= RapidApp::Spreadsheet::ExcelTableWriter->new(
    wbook => $xls,
    wsheet => $xls->add_worksheet("MyData"),
    columns => [ 'Foo', 'Bar', 'Baz' ]
  );
  
  my $tw= RapidApp::Spreadsheet::ExcelTableWriter->new(
    wbook => $xls,
    wsheet => $xls->add_worksheet("MyData"),
    columns => [
      { name => 'foo_1', label => 'Foo', isString => 0 },
      { name => 'bar', label => 'Bar', format => $xls->add_format(bold => 1) },
      { name => 'baz', label => 'BAAAAZZZZZ!' },
    ],
    headerFormat => $xls->add_format(bold => 1, underline => 1, italic => 1),
  );
  
  $tw->writePreamble("Some descriptive text at the top of the file");
  $tw->writePreamble;
  $tw->writeHeaders;    # optional so long as writeRow gets called
  
  $tw->writeRow(1, 'John Doe', '1234 Reading Rd');
  $tw->writeRow( [ 2, 'Bob Smith', '1234 Eagle Circle');
  $tw->writeRow( { foo_1 => 3, bar => 'Rand AlThor', baz => 'Royal Palace, Cairhien' } );
  
  $tw->autosizeColumns;

=cut

use strict;
use warnings;
use Moose;

use Spreadsheet::ParseExcel;
use RapidApp::Spreadsheet::ParseExcelExt;

has 'wbook'    => ( is => 'ro', isa => 'Excel::Writer::XLSX::Workbook', required => 1 );
has 'wsheets'  => ( is => 'ro', isa => 'ArrayRef', required => 1 );
has 'columns'  => ( is => 'rw', isa => 'ArrayRef', required => 1 );
has 'rowStart' => ( is => 'rw', isa => 'Int', required => 1, default => 0 );
has 'colStart' => ( is => 'rw', isa => 'Int', required => 1, default => 0 );
has 'headerFormat' => ( is => 'rw', lazy_build => 1 );
has 'ignoreUnknownRowKeys' => ( is => 'rw', isa => 'Bool', default => 0 );

sub _build_headerFormat {
	my $self= shift;
	return $self->wbook->add_format(bold => 1, bottom => 1);
}

sub colCount {
	my $self= shift;
	return scalar(@{$self->columns});
}

around 'BUILDARGS' => sub {
	my $orig= shift;
	my $class= shift;
	my $args= $class->$orig(@_);
	if (defined $args->{wsheet}) {
		$args->{wsheets}= [ $args->{wsheet} ];
		delete $args->{wsheet};
	}
	return $args;
};

sub numWsRequired($) {
	my ($unused, $numCols)= @_;
	use integer;
	return ($numCols+255) / 256;
}

sub BUILD {
	my $self= shift;
	
	my $numWsNeeded= $self->numWsRequired(scalar(@{$self->columns}));
	$numWsNeeded <= scalar(@{$self->wsheets})
		or die "Not enough worksheets allocated for ExcelTableWriter (got ".scalar(@{$self->wsheets}).", require $numWsNeeded)";
	
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

=head2 curRow

Returns the next row that will be written by a call to writePreamble, writeHeadrs, or writeRow.

This value is read-only

=cut
  
sub curRow {
	my $self= shift;
	defined $self->{_curRow} and return $self->{_curRow};
	return $self->rowStart;
}

has '_documentStarted' => ( is => 'rw' );
has '_dataStarted' => ( is => 'rw' );

=head2 excelColIdxToLetter

  print RapidApp::Spreadsheet::ExcelTableWriter->excelColIdxToLetter(35);
  # prints AM
  print $tableWriter->excelColIdxToLetter(0);
  # prints A

=cut

use Spreadsheet::ParseExcel::Utility 'int2col';

sub excelColIdxToLetter($) {
	my ($ignored, $colNum)= @_;
	return int2col($colNum);
}

sub sheetForCol {
	my ($self, $colIdx)= @_;
	use integer;
	$colIdx+= $self->colStart;
	return $self->wsheets->[$colIdx / 256], $colIdx%256;
}

sub _applyColumnFormats {
	my $self= shift;
	
	for (my $i=0; $i < $self->colCount; $i++) {
		my $fmt= $self->columns->[$i]->format;
		my $wid= $self->columns->[$i]->width eq 'auto'? undef : $self->columns->[$i]->width;
		
		my ($wsheet, $sheetCol)= $self->sheetForCol($i);
		$wsheet->set_column($sheetCol, $sheetCol, $wid, $fmt);
	}
}

sub prepareDocument {
	my $self= shift;
	!$self->_documentStarted or die 'column formats can only be applied before the first "write"';
	
	$self->_applyColumnFormats();
	$self->_documentStarted(1);
}

=head2 writePreamble

writePreamble writes each of its arguments into an Excel cell from left to right, and then
increments the current row.

The only purpose of this routine is to conveniently increment the starting row while writing
various bits of text at the start of the worksheet.

=cut

sub writePreamble {
	my ($self, @args)= @_;
	!$self->_dataStarted or die 'Preamble must come before headers and data';
	
	$self->_documentStarted or $self->prepareDocument;
	for (my $i=0; $i < scalar(@args); $i++) {
		my ($ws, $wsCol)= $self->sheetForCol($i);
		$ws->write($self->curRow, $wsCol, $args[$i]);
	}
	$self->{_curRow}++;
}

=head2 writeHeaders

writeHeaders takes no parameters and returns nothing.  It simply writes out the column header row
in the current headerFormat, and changes the state of the object to "writing rows".

writeheaders can only be called once.  No more writePreamble calls can be made after writeHeaders.

=cut

sub writeHeaders {
	my $self= shift;
	!$self->_dataStarted or die 'Headers cannot be written twice';
	
	$self->_documentStarted or $self->prepareDocument;
	for (my $i=0; $i < $self->colCount; $i++) {
		my ($ws, $wsCol)= $self->sheetForCol($i);
		$ws->write_string($self->curRow, $wsCol, $self->columns->[$i]->label, $self->headerFormat);
		$self->columns->[$i]->updateWidest(length($self->columns->[$i]->label)*1.2);
	}
	$self->_dataStarted(1);
	$self->{_curRow}++;
}




=head2 writeRow

  $tableWriter->writeRow( \@rowdata );
  $tableWriter->writeRow( { col1_name => col1_val, col2_name => col2_val ... } );
  $tableWriter->writeRow( @rowData );

=over

=item Arguments: \@rowdata or \%rowhash or @rowdata

=item Returns: true

=back

The most optimal parameter is an array of elements in the same order as the columns were defined.

Alternatively, a hash can be used, with the name of the columns as keys.

If the first parameter is not a array/hash reference, the argument array is treated as the data array.

=cut
our $writeRowFormat; #<-- quick/dirty global var for 'format' (see $workbook->add_format in Excel::Writer::XLSX)
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
		my ($ws, $wsCol)= $self->sheetForCol($i);
		
		my @args = ($self->curRow, $wsCol, $rowData->[$i]);
		push @args, $writeRowFormat if ($writeRowFormat);
		
		$ws->write(@args);
		
		# -- this logic is dumb and doesn't work right. 'write' already does smart setting of the
		# type. (commented out by HV on 2012-05-26)
		#if ($self->columns->[$i]->isString) {
		#	$ws->write_string(@args);
		#} else {
		#	$ws->write(@args);
		#}
		# --
		
		$self->columns->[$i]->updateWidest(length $rowData->[$i]) if (defined $rowData->[$i]);
	}
	$self->{_curRow}++;
}

sub rowHashToArray {
	my ($self, $hash)= @_;
	my $result= [];
	my $seen= 0;
	for my $col (@{$self->columns}) {
		exists $hash->{$col->name} and $seen++;
		push @$result, $hash->{$col->name};
	}
	
	# elaborate error check, to be helpful....
	if (!$self->ignoreUnknownRowKeys && scalar(keys(%$hash)) != $seen) {
		my %tmphash= %$hash;
		map { delete $tmphash{$_->name} } @{$self->columns};
		warn "Unused keys in row hash: ".join(',',keys(%tmphash));
	}
	return $result;
}

=head2 autosizeColumns

  $tableWriter->writeRow
  $tableWriter->writeRow
  $tableWriter->writeRow
  ...
  $tableWriter->autosizeColumns

=over

=item Arguments: none

=item Returns: none

AutosizeColumns should be called after all data has been written.  As each row is written, a 
max width is updated per column. Calling autosizeColumns sets the excel column width to these
maximum values.

=back

=cut
sub autosizeColumns {
	my $self= shift;
	for (my $i=0; $i < $self->colCount; $i++) {
		if ($self->columns->[$i]->width eq 'auto') {
			my ($ws, $wsCol)= $self->sheetForCol($i);
			$ws->set_column($wsCol, $wsCol, $self->columns->[$i]->widest+.5);
		}
	}
}

1;