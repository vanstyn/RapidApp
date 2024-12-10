# -*- perl -*-

use strict;
use warnings;
use Test::More;
use File::Temp;
plan skip_all => "Need ParseXLSX installed"
  unless eval { require Spreadsheet::ParseXLSX };

use RapidApp::Spreadsheet::ExcelTableWriter;
use Excel::Writer::XLSX;

my $temp= File::Temp->newdir(CLEANUP=>0);
note "temp = $temp";

subtest column_formats => sub {
  my $wb= Excel::Writer::XLSX->new("$temp/test_formats.xlsx");
  my $ws= $wb->add_worksheet();

  my $writer= RapidApp::Spreadsheet::ExcelTableWriter->new(
    wbook   => $wb,
    wsheet  => $ws,
    columns => [
      'col1',
      { name => 'col2', type => 'text' },
      { name => 'col3', type => 'number' },
      { name => 'col4', type => 'datetime' },
      { name => 'col5', type => 'bool' },
    ]
  );
  $writer->writeRow('0123.0', '0123.0', '0123.0', '2020-01-01 00:00:01', '0123');
  undef $writer;
  undef $ws;
  $wb->close();
  undef $wb;

  my $parser= Spreadsheet::ParseXLSX->new;
  $wb= $parser->parse("$temp/test_formats.xlsx");
  $ws= $wb->worksheet(0);
  is( $ws->get_cell(1, 0)->value(), '0123.0', 'column type "auto" preserves leading/trailing zeroes' );
  is( $ws->get_cell(1, 1)->value(), '0123.0', 'column type "text" preserves leading/trailing zeroes' );
  is( $ws->get_cell(1, 2)->value(), 123, 'column type "number" loses zeroes' );
  is( $ws->get_cell(1, 3)->unformatted(), '43831.0000115741', 'column type "datetime" was stored as a number (excel date)' );
  is( $ws->get_cell(1, 3)->value(), '2020-01-01 00:00:01', 'column type "datetime" round-trips as text' );
  is( $ws->get_cell(1, 4)->value(), 'TRUE', 'column type "bool" round-trips as TRUE' );
};

undef $temp;

done_testing;

 