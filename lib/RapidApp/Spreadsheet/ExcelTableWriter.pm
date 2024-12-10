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

use Moose;
use Data::Dumper ();
use Spreadsheet::ParseExcel;
use RapidApp::Spreadsheet::ExcelTableWriter::ColDef;
use Scalar::Util 'looks_like_number';
use namespace::clean;

has 'wbook'    => ( is => 'ro', isa => 'Excel::Writer::XLSX::Workbook', required => 1 );
has 'wsheets'  => ( is => 'ro', isa => 'ArrayRef', required => 1 );
has 'columns'  => ( is => 'rw', isa => 'ArrayRef', required => 1 );
has 'rowStart' => ( is => 'rw', isa => 'Int', required => 1, default => 0 );
has 'colStart' => ( is => 'rw', isa => 'Int', required => 1, default => 0 );
has _format_cache  => ( is => 'rw', default => sub { +{} } );
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

# Extreme column counts wrap to new worksheets

sub _max_sheet_cols {
	ref($_[0]->wbook) =~ /XLSX/? 16384 : 256;
}

sub numWsRequired($) {
	my ($self, $numCols)= @_;
	my $max_cols= $self->_max_sheet_cols;
	$numCols //= @{$self->columns};
	use integer;
	return ($numCols + $max_cols - 1) / $max_cols;
}

sub sheetForCol {
	my ($self, $colIdx)= @_;
	my $max_cols= $self->_max_sheet_cols;
	use integer;
	$colIdx+= $self->colStart;
	return $self->wsheets->[$colIdx / $max_cols], $colIdx % $max_cols;
}

sub get_cached_format {
	my ($self, $spec)= @_;
	my $key= Data::Dumper->new([$spec])->Terse(1)->Sortkeys(1)->Dump;
	$self->_format_cache->{$key} //= $self->wbook->add_format(%$spec);
}

our %default_format_for_type= (
  auto     => undef,
  text     => { num_format => '@' },
  number   => undef,
  date     => { num_format => 'YYYY-MM-DD' },
  time     => { num_format => 'HH:MM:SS AM/PM' },
  datetime => { num_format => 'YYYY-MM-DD HH:MM:SS' },
  bool     => { num_format => 'BOOLEAN' },
  formula  => undef,
);

sub BUILD {
	my $self= shift;
	
	my $num_sheets_needed= $self->numWsRequired;
	$num_sheets_needed <= scalar(@{$self->wsheets})
		or die "Not enough worksheets allocated for ExcelTableWriter (got ".scalar(@{$self->wsheets}).", require $num_sheets_needed)";
	
	for (@{$self->columns}) {
		# convert hashes into the proper object
		$_= RapidApp::Spreadsheet::ExcelTableWriter::ColDef->new($_)
			if ref $_ eq 'HASH';
		# convert scalars into names (and labels)
		$_= RapidApp::Spreadsheet::ExcelTableWriter::ColDef->new(name => $_)
			if !ref;
		# create format objects if they were supplied as hashrefs
		my $fmt= $_->format // $default_format_for_type{$_->type};
		$fmt= $self->get_cached_format($fmt) if ref $fmt eq 'HASH';
		$_->_format_obj($fmt);
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
	int2col($_[1]);
}

sub _applyColumnFormats {
	my $self= shift;
	my %format_cache;
	
	for (my $i=0; $i < $self->colCount; $i++) {
		my $wid= $self->columns->[$i]->width eq 'auto'? undef : $self->columns->[$i]->width;
		my $fmt= $self->columns->[$i]->_format_obj;
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
		# 1.2 multiplier is a guess since bold text is wider
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
	my %type_method= (
		bool     => 'write_boolean',
		number   => 'write_number',
		formula  => 'write_formula',
		date     => \&_coerce_and_write_date_time,
		time     => \&_coerce_and_write_date_time,
		datetime => \&_coerce_and_write_date_time,
		text     => \&_write_string_or_url,
		auto     => \&_write_auto,
	);
	
	for (my $i=0; $i < $self->colCount; $i++) {
		my $colDef= $self->columns->[$i];
		my ($ws, $wsCol)= $self->sheetForCol($i);
		my $val= $rowData->[$i];
		# Always export NULLs as empty cells, regardless of type
		next unless defined $val;
    
		# The default 'write' method checks the value against patterns to choose how to encode it.
		# This can be a problem if strings with leading or trailing zeroes are meant to be encoded
		# as strings, or if strings starting with '=' were not intended to be executed as formulae
		# (opportunity for injection attack, though often disabled in newer Excel versions)
		my $t= $colDef->type;
		my $method= $type_method{$t} // 'write_string';
		$ws->$method($self->curRow, $wsCol, $val,
			(defined $writeRowFormat? ($writeRowFormat):()));

		$colDef->updateWidest(length $val);
	}
	$self->{_curRow}++;
}

# The XLSX write_date_time function requires the 'T' character to differentiate
# between dates and times.  DBIC doesn't always supply it.  Also it can't include
# a time zone.
sub _coerce_and_write_date_time {
	#my ($ws, $col, $row, $val, $fmt)= @_;
	my $val= $_[3];
	splice(@_, 3, 1, $val) # don't modify $_[3], out of caution.
		if # 'or', except need to test all 3 regexes and not skip the last one
		+ ($val =~ s/^(\d{4}-\d{2}-\d{2})( |$)/$1T/)  # add T on date
		+ ($val =~ s/^(\d{2}:\d{2}:\d{2})$/T$1/)      # add T before time
		+ ($val =~ s/^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?)\+0+/$1/); # remove '+00' timezone of postgres
		# any other pattern gets written as a string.  Might be cases where this should
		# fully parse and re-format the date...
	&{$_[0]->can('write_date_time')}
}
# Auto-upgrade to URLs with different logic than Writer::XLSX
# allow any URL with mailto: or (\w+)://
sub _write_string_or_url {
	#my ($ws, $col, $row, $val, $fmt)= @_;
	$_[3] =~ m,^(?|mailto:|\w+://),
		? &{$_[0]->can('write_url')}
		: &{$_[0]->can('write_string')}
}
sub _write_auto {
	#my ($ws, $col, $row, $val, $fmt)= @_;
	# Only convert to numbers if no leading or trailing zeroes
	looks_like_number($_[3]) && $_[3] !~ /^0/ && $_[3] !~ /0$/
		? &{$_[0]->can('write_number')}
		: &_write_string_or_url;
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
	if (!$self->ignoreUnknownRowKeys && scalar(keys %$hash) != $seen) {
		my %tmphash= %$hash;
		delete $tmphash{$_->name} for @{$self->columns};
		warn "Unused keys in row hash: ".join(',',keys %tmphash);
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