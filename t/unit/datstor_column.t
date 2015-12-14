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



ok(
  $Col = RapidApp::Module::DatStor::Column->new({ 
    name      => 'col',
    editor    => { xtype => 'textfield' },
    allow_edit => 0
  }),
  "[5] Object construction success"
);
$Col->apply_attributes;

ok(! $Col->no_column  => "[5] no_column is false as expected");
ok(! $Col->allow_add  => "[5] allow_add is false as expected");
ok(! $Col->allow_edit => "[5] allow_edit is false as expected");
ok(! $Col->allow_view => "[5] allow_view is false as expected");


ok(
  $Col = RapidApp::Module::DatStor::Column->new({ 
    name      => 'col',
    editor    => { xtype => 'textfield' },
    allow_edit => 0, allow_add => 1
  }),
  "[6] Object construction success"
);
$Col->apply_attributes;

ok(! $Col->no_column  => "[6] no_column is false as expected");
ok(  $Col->allow_add  => "[6] allow_add is true as expected");
ok(! $Col->allow_edit => "[6] allow_edit is false as expected");
ok(! $Col->allow_view => "[6] allow_view is false as expected");



ok(
  $Col = RapidApp::Module::DatStor::Column->new({ 
    name      => 'col',
    editor    => { xtype => 'textfield' },
    no_column => 1, allow_add => 1
  }),
  "[7] Object construction success"
);
$Col->apply_attributes;

ok(  $Col->no_column  => "[7] no_column is true as expected");
ok(  $Col->allow_add  => "[7] allow_add is true as expected");
ok(! $Col->allow_edit => "[7] allow_edit is false as expected");
ok(! $Col->allow_view => "[7] allow_view is false as expected");



ok(
  $Col = RapidApp::Module::DatStor::Column->new({ 
    name      => 'col',
    editor    => { xtype => 'textfield' },
    no_column => 1, allow_view => 1
  }),
  "[8] Object construction success"
);
$Col->apply_attributes;

ok(  $Col->no_column  => "[8] no_column is true as expected");
ok(! $Col->allow_add  => "[8] allow_add is false as expected");
ok(! $Col->allow_edit => "[8] allow_edit is false as expected");
ok(  $Col->allow_view => "[8] allow_view is true as expected");


ok(
  $Col = RapidApp::Module::DatStor::Column->new({ 
    name      => 'col',
    editor    => { xtype => 'textfield' },
    no_column => \1, allow_view => \0
  }),
  "[9] Object construction success"
);
$Col->apply_attributes;

ok(  $Col->no_column  => "[9] no_column is true as expected");
ok(! $Col->allow_add  => "[9] allow_add is false as expected");
ok(! $Col->allow_edit => "[9] allow_edit is false as expected");
ok(! $Col->allow_view => "[9] allow_view is false as expected");


ok(
  $Col = RapidApp::Module::DatStor::Column->new({ 
    name      => 'timeslot_id',
    editor    => { xtype => 'textfield' },
    no_column => \1, allow_view => \0, allow_edit => \0
  }),
  "[10] Object construction success"
);
$Col->apply_attributes;

ok(  $Col->no_column  => "[10] no_column is true as expected");
ok(! $Col->allow_add  => "[10] allow_add is false as expected");
ok(! $Col->allow_edit => "[10] allow_edit is false as expected");
ok(! $Col->allow_view => "[10] allow_view is false as expected");



ok(
  $Col = RapidApp::Module::DatStor::Column->new({ 
    width => 110, 	header => 'Col',
    editor    => { xtype => 'textfield' }, 
  }),
  "[11] Object construction success"
);
$Col->apply_attributes;

ok(! $Col->no_column  => "[11] no_column is false as expected");
ok(  $Col->allow_add  => "[11] allow_add is true as expected");
ok(  $Col->allow_edit => "[11] allow_edit is true as expected");
ok(  $Col->allow_view => "[11] allow_view is true as expected");





done_testing;
