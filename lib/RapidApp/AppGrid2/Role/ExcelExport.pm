package RapidApp::AppGrid2::Role::ExcelExport;

use strict;
use warnings;
use Moose::Role;

use Spreadsheet::WriteExcel;
use RapidApp::Spreadsheet::ExcelTableWriter;



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
		text		=> 'Excel Export',
		iconCls	=> 'icon-excel',
		handler	=>  RapidApp::JSONFunc->new( 
			raw => 1, 
			func => 'function(cmp) { ' . 
				'var grid = cmp.findParentByType("appgrid2");' .
			
				'Ext.Msg.show({ ' .
					'title: "Excel Export",' . 
					'msg: "Export current view to Excel File? <br><br>(This might take up to a few minutes depending on the number of rows)",' .
					'buttons: Ext.Msg.YESNO, fn: function(sel){' .
						'if(sel != "yes") return; ' .
						
						'var store = grid.getStore();' .
						'var url = "' . $self->suburl('/excel_read') . '";' .
						'var params = {};' .
						'for (i in store.lastOptions.params) {' .
							'if (i != "start" && i != "limit") {' .
								'params[i] = store.lastOptions.params[i];' .
							'}' .
						'}' .
						'Ext.ux.postwith(url,params);' .
						
						#'document.location.href=url + "?" + Ext.urlEncode(params);' .
					'},' .
					'scope: cmp' .
				'});' .
			'}' 
		)
	};
	
	return $items;
};




sub excel_read {
	my $self = shift;
	my $params = $self->c->req->params;
	
	my $dlData = '';
	open my $fd, '>', \$dlData;
	
	my $data = $self->store_read;
	
	my @headers = ();
	my @fields = ();
	foreach my $col (@{$self->column_order}) {
		my $field = $self->columns->{$col} or die "column $col does not exist in columns hash";
		next if ($field->{name} eq 'icon');
		next unless (defined $field->{header} and defined $field->{name});
		push @headers, $field->{header};
		push @fields, $field->{name};
	}
	
	my $xls = Spreadsheet::WriteExcel->new($fd);
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
		columns	=> \@headers
	);
	
	#$tw->writePreamble('Clippard Instrument Laboratory');
	#$tw->writePreamble('Export of Project Data');
	#$tw->writePreamble();
	
	# This doesn't work do to bug in RapidApp::Spreadsheet::ExcelTableWriter:
	#foreach my $row (@{ $data->{rows} }) {
	#	$tw->writeRow($row)
	#}
	

	foreach my $row (@{ $data->{rows} }) {
		my @r = ();
		foreach my $fname (@fields) {
			push @r, $row->{$fname};
		}
		$tw->writeRow(@r);
	}


	$tw->autosizeColumns();
	$xls->close();
	
		
	$self->render_as_json(0);

	my $h= $self->c->res->headers;
	$h->content_type('application/x-download');
	$h->content_length(do { use bytes; length($dlData) });
	$h->last_modified(time);
	$h->header('Content-disposition' => "attachment; filename=\"export.xls\"");
	$h->expires(time());
	$h->header('Pragma' => 'no-cache');
	$h->header('Cache-Control' => 'no-cache');
	
	return $dlData;
}



1;
