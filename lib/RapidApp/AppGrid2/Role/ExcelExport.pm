package RapidApp::AppGrid2::Role::ExcelExport;

use strict;
use warnings;
use Moose::Role;

use Excel::Writer::XLSX;
use RapidApp::Spreadsheet::ExcelTableWriter;
use RapidApp::Include qw(perlutil sugar);

sub BUILD {}
before 'BUILD' => sub {
	my $self = shift;
	
	$self->apply_actions( excel_read => 'excel_read' );
};


around 'options_menu_items' => sub {
	my $orig = shift;
	my $self = shift;
	
	my $items = $self->$orig(@_);
	$items = [] unless (defined $items);
	
	push @$items, {
		text => 'Excel Export',
		hideOnClick => \0,
		iconCls	=> 'icon-page-excel',
		menu => RapidApp::JSONFunc->new( func => 'new Ext.ux.RapidApp.AppTab.AppGrid2.ExcelExportMenu',
			parm => {
				url	=> $self->suburl('/excel_read'),
				# This shouldn't be required, but the sub menu's loose track of their parents!!
				buttonId => $self->options_menu_button_Id
			}
		)
	};
	
	return $items;
};

sub excel_read {
	my $self = shift;
	my $params = $self->c->req->params;
	
	my $export_filename = $params->{export_filename} || 'export';
	$export_filename .= '.xlsx' unless ($export_filename =~ /\.xlsx$/);
	delete $params->{export_filename};
	
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
		next if ${ $field->no_column };
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
	
	my $dlData = '';
	open my $fd, '>', \$dlData;
	
	my $xls = Excel::Writer::XLSX->new($fd);
	
	# -- Excel/Writer/XLSX-specific: (slashes used instead of :: to protect from find/replace)
	$xls->set_optimization();
	# --
	
	$xls->set_properties(
		title    => 'Exported RapidApp AppGrid Module: ' . ref($self),
		#company  => 'Clippard Instrument Laboratory',
		#author   => 'IntelliTree Solutions',
		#comments => 'Export of current database data',
	);
	my $ws = $xls->add_worksheet;
	my $tw = RapidApp::Spreadsheet::ExcelTableWriter->new(
		wbook		=> $xls,
		wsheet	=> $ws,
		columns	=> \@colDefs,
		ignoreUnknownRowKeys => 1,
	);
	
	#$tw->writePreamble('Clippard Instrument Laboratory');
	#$tw->writePreamble('Export of Project Data');
	#$tw->writePreamble();
	
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
	
	$self->render_as_json(0);
	
	my $h= $self->c->res->headers;
	
	#$h->content_type('application/x-download');
	
	# Excel 97-2003 format (XLS)
	#$h->content_type('application/vnd.ms-excel');
	
	# Generic Spreadsheet format
	#$h->content_type('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
	
	# Excel XLSX format
	$h->content_type('application/vnd.ms-excel.12');
	
	# Make it a file download:
	$h->header('Content-disposition' => "attachment; filename=\"$export_filename\"");

	$h->content_length(do { use bytes; length($dlData) });
	$h->last_modified(time);
	$h->expires(time());
	$h->header('Pragma' => 'no-cache');
	$h->header('Cache-Control' => 'no-cache');
	
	return $dlData;
}


sub convert_render_cols_hash {
	my $self = shift;
	my $hash = shift;
	
	foreach my $col (keys %$hash) {
		my $field = $self->get_column($col) or die "column $col does not exist in columns hash";
		my $colname = $field->render_column ? $field->render_column : $field->name;
		$hash->{$colname} = delete $hash->{$col};
	}
}


1;
