# -*- perl -*-

use strict;
use warnings;
use FindBin '$Bin';
use lib "$Bin/lib";

use Test::More;
use RapidApp::Util ':all';

require_ok('RapidApp::Module::DatStor::Column');

my $Col;

ok(
  $Col = RapidApp::Module::DatStor::Column->new({ name => 'col' }),
  "Object construction success"
);
$Col->apply_attributes;

ok(! $Col->no_column  => "no_column is false as expected");
ok(! $Col->allow_add  => "allow_add is false as expected");
ok(! $Col->allow_edit => "allow_edit is false as expected");
ok(  $Col->allow_view => "allow_view is true as expected");


ok(
  $Col = RapidApp::Module::DatStor::Column->new({ 
    name   => 'col',
    editor => { xtype => 'textfield' }
  }),
  "[2] Object construction success"
);
$Col->apply_attributes;

ok(! $Col->no_column  => "[2] no_column is false as expected");
ok(  $Col->allow_add  => "[2] allow_add is true as expected");
ok(  $Col->allow_edit => "[2] allow_edit is true as expected");
ok(  $Col->allow_view => "[2] allow_view is true as expected");


ok(
  $Col = RapidApp::Module::DatStor::Column->new({ 
    name      => 'col',
    editor    => { xtype => 'textfield' },
    no_column => 1
  }),
  "[3] Object construction success"
);
$Col->apply_attributes;

ok(  $Col->no_column  => "[3] no_column is true as expected");
ok(! $Col->allow_add  => "[3] allow_add is false as expected");
ok(! $Col->allow_edit => "[3] allow_edit is false as expected");
ok(! $Col->allow_view => "[3] allow_view is false as expected");


ok(
  $Col = RapidApp::Module::DatStor::Column->new({ 
    name      => 'col',
    editor    => { xtype => 'textfield' },
    no_column => 1,
    allow_add => 1
  }),
  "[4] Object construction success"
);
$Col->apply_attributes;

ok(  $Col->no_column  => "[4] no_column is true as expected");
ok(  $Col->allow_add  => "[4] allow_add is true as expected");
ok(! $Col->allow_edit => "[4] allow_edit is false as expected");
ok(! $Col->allow_view => "[4] allow_view is false as expected");




done_testing;
