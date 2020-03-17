package RapidApp::Module::Grid::Role::ExcelExport;

use strict;
use warnings;
use Moose::Role;

use Excel::Writer::XLSX;
use RapidApp::Spreadsheet::ExcelTableWriter;
use RapidApp::Util qw(:all);
require JSON;
require Text::CSV;
use DateTime;

sub BUILD {}
before 'BUILD' => sub {
	my $self = shift;

	$self->apply_actions( export_to_file => 'export_to_file' );
};


around 'options_menu_items' => sub {
	my $orig = shift;
	my $self = shift;

	my $items = $self->$orig(@_);
	$items = [] unless (defined $items);

	push @$items, {
		text => 'Download As...',
		hideOnClick => \0,
		iconCls	=> 'ra-icon-document-save',
		menu => RapidApp::JSONFunc->new( func => 'new Ext.ux.RapidApp.AppTab.AppGrid2.ExcelExportMenu',
			parm => {
				url => $self->local_url('/export_to_file'),
				# This shouldn't be required, but the sub menu's loose track of their parents!!
				buttonId => $self->options_menu_button_Id
			}
		)
	};

	return $items;
};

my $xlsx_mime= 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
my %formats= map { $_->{mime} => $_ } (
	{ mime => 'text/csv',                  file_ext => '.csv',  renderer => 'export_render_csv' },
	{ mime => 'text/tab-separated-values', file_ext => '.tsv',  renderer => 'export_render_tsv' },
	{ mime => 'application/json',          file_ext => '.json', renderer => 'export_render_json' },
	{ mime => $xlsx_mime,                  file_ext => '.xlsx', renderer => 'export_render_excel' },
);
sub export_to_file {
	my $self = shift;
	my $params = $self->c->req->params;

	# Determine output format, defaulting to CSV
	my $export_format= $formats{$params->{export_format}} || $formats{'text/csv'};

	# Determine file name, defaulting to 'export', and apply the default file extension.
	my $export_filename = $params->{export_filename} || 'export';

  # New: append the current date/time to the export filename:
  my $dt = DateTime->now( time_zone => 'local' );
  $export_filename .= join('','-',$dt->ymd('-'),'_',$dt->hms(''));

	$export_filename .= $export_format->{file_ext}
		unless substr($export_filename,-length($export_format->{file_ext})) eq $export_format->{file_ext};

	# Clean up params so that AppGrid doesn't get confused
	delete $params->{export_filename};
	delete $params->{export_format};

	# Get the list of desired columns from the query parameters.
	# If not specified, we use all defined columns.
	my $columns= ($params->{columns})
		? $self->json->decode($params->{columns})
		: $self->column_order;

	# filter out columns that we can't use, and also build the column definitions for ExcelTableWriter
	my @colDefs = ();
	foreach my $col (@$columns) {
		my $field = $self->get_column($col) or die "column $col does not exist in columns hash";

		# New: If render_column is defined, use it instead of name
		my $colname = $field->render_column ? $field->render_column : $field->name;

		next if ($field->name eq 'icon');
		next if $field->no_column;
		next unless (defined $field->header and defined $field->name);
		push @colDefs, {
			name => $colname,
			label => $field->header
		};
	}

	# Restrict columns to the set we chose to keep.
	# Note that the previous ref is a constant, and would be bad if we modified it.
	$columns= [ map { $_->{name} } @colDefs ];

	# override the columns that DataStore is fetching
	#$self->c->req->params->{columns}= $self->json->encode($columns);
	my $data = $self->DataStore->read({%$params, columns => $columns, ignore_page_size => 1});

	# TODO: We just read all rows into memory, and now we're building the file in memory as well.
	# We would do well to replace this with a db-cursor-to-tempfile streaming design

	my $dlData = '';
	open my $fd, '>', \$dlData;

	my $method= $export_format->{renderer};
	$self->$method({ %$params, col_defs => \@colDefs }, $data, $fd);

	close $fd;

	$self->render_as_json(0);

	my $h= $self->c->res->headers;

	# Excel 97-2003 format (XLS)
	#$h->content_type('application/vnd.ms-excel');

	# Generic Spreadsheet format
	#$h->content_type('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

	# Excel XLSX format
	#$h->content_type('application/vnd.ms-excel.12');
	$h->content_type($export_format->{mime});

	# Make it a file download:
	$h->header('Content-disposition' => "attachment; filename=\"$export_filename\"");

	$h->content_length(do { use bytes; length($dlData) });
	$h->last_modified(time);
	$h->expires(time());
	$h->header('Pragma' => 'no-cache');
	$h->header('Cache-Control' => 'no-cache');

	return $dlData;
}

sub export_render_excel {
	my ($self, $params, $data, $fd)= @_;

	my $xls = Excel::Writer::XLSX->new($fd);

	# -- Excel/Writer/XLSX-specific: (slashes used instead of :: to protect from find/replace)
	$xls->set_optimization();
	# --

	$xls->set_properties(
		title    => 'Exported RapidApp AppGrid Module: ' . ref($self),
	);
	my $ws = $xls->add_worksheet;
	my $tw = RapidApp::Spreadsheet::ExcelTableWriter->new(
		wbook	=> $xls,
		wsheet	=> $ws,
		columns	=> $params->{col_defs},
		ignoreUnknownRowKeys => 1,
	);

	#########################################
	$tw->writeRow($_) for (@{$data->{rows}});
	#########################################

	#### Column Summaries ####
	if(exists $data->{column_summaries}) {
		my $sums = $data->{column_summaries};
		$self->convert_render_cols_hash($sums);

		my $funcs;
		if ($params->{column_summaries}) {
			$funcs = $self->json->decode($params->{column_summaries});
			$self->convert_render_cols_hash($funcs);
		}

		$tw->writeRow({});
		$tw->writeRow({});
		my $fmt = $xls->add_format;
		$fmt->set_bold();
		local $RapidApp::Spreadsheet::ExcelTableWriter::writeRowFormat = $fmt;
		$tw->writeRow('Col Summaries');
		$fmt->set_italic();

		if($data->{results} && $data->{results} > @{$data->{rows}}) {
			my $fmt = $xls->add_format;
			$fmt->set_italic();
			local $RapidApp::Spreadsheet::ExcelTableWriter::writeRowFormat = $fmt;
			$tw->writeRow('(Note: all rows are not shown above)');
		}
		$tw->writeRow({});
		$tw->writeRow($funcs) if ($funcs);

		$RapidApp::Spreadsheet::ExcelTableWriter::writeRowFormat = undef;
		$tw->writeRow($sums);
	}
	####

	$tw->autosizeColumns();
	$xls->close();
}

sub export_render_csv {
	my ($self, $params, $data, $fd)= @_;
	my $csv= Text::CSV->new({ binary => 1 }) or die "Can't create CSV instance";

	my @cols= map { $_->{name} } @{ $params->{col_defs} };
	my @titles= map { $_->{label} } @{ $params->{col_defs} };

	# Write header row
	$csv->print($fd, \@titles);
	print $fd "\r\n";

	# Write data rows
	for (@{ $data->{rows} }) {
		$csv->print($fd, [ @{$_}{@cols} ]);
		print $fd "\r\n";
	}
}

sub export_render_tsv {
	my ($self, $params, $data, $fd)= @_;
	my $csv= Text::CSV->new({ binary => 1, sep_char => "\t", quote_space => 0 }) or die "Can't create CSV instance";

	my @cols= map { $_->{name} } @{ $params->{col_defs} };
	my @titles= map { $_->{label} } @{ $params->{col_defs} };

	# Write header row
	$csv->print($fd, \@titles);
	print $fd "\r\n";

	# Write data rows
	for (@{ $data->{rows} }) {
		$csv->print($fd, [ @{$_}{@cols} ]);
		print $fd "\r\n";
	}
}

sub export_render_json {
	my ($self, $params, $data, $fd)= @_;

	my $json= JSON->new->ascii(1);
	my @cols= map { $_->{name} } @{ $params->{col_defs} };

	# Export row-by-row for two reasons:
	#   First, it prevents us from making 3 full copies of the whole
	#   dataset in memory (could run the server out of ram)
	#   and Second, if we insert a newline after each row then it won't
	#   break text viewers (like less) as badly as if they try to view
	#   several MB of data on a single line.
	$fd->print("{\"columns\":" . $json->encode($params->{col_defs}) . ",\r\n"
		." \"rows\":[");
	for (my $i= 0; $i < @{ $data->{rows} }; $i++) {
		my %row;
		# Unfortunately the data might contain extra columns like the primary keys,
		# and we might not want to show these to users.  (Think SSNs)
		# So we have to perform a translation on each row to extract only the columns we should export.
		@row{@cols}= @{$data->{rows}[$i]}{@cols};
		$fd->print($i? ",\r\n  " : "\r\n  ");
		$fd->print($json->encode(\%row));
	}
	$fd->print("\r\n ]");
	if (exists $data->{column_summaries}) {
		$fd->print(",\r\n \"column_summaries\":");
		$fd->print($json->encode($data->{column_summaries}));
	}
	$fd->print("\r\n}");
}

sub convert_render_cols_hash {
	my $self = shift;
	my $hash = shift;

	foreach my $col (keys %$hash) {
		my $field = $self->get_column($col) or
      warn "ExcelExport: column $col does not exist in columns hash"
      and next;
		my $colname = $field->render_column ? $field->render_column : $field->name;
		$hash->{$colname} = delete $hash->{$col};
	}
}


1;
