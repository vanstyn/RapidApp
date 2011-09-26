#! /usr/bin/perl

use strict;
use Test::More;
use Try::Tiny;

use lib 't/lib';
use FakeSchema;
my $db= FakeSchema->new({
	Object   => { columns => [qw[ id owner_id creator_id is_deleted ]], rels => { user => 'User', contact => 'Contact', owner => 'User', creator => 'User' } },
	User     => { columns => [qw[ object_id username password ]], rels => {} },
	Contact  => { columns => [qw[ object_id first last timezone_id ]], rels => { timezone => 'Timezone' } },
	Timezone => { columns => [qw[ id name abbrev ofs ]], rels => {} },
});

use_ok('RapidApp::DBIC::RelationTreeSpec');
use_ok('RapidApp::DBIC::RelationTreeFlattener');

my $spec= RapidApp::DBIC::RelationTreeSpec->new(
	source => $db->source('Object'),
	colSpec => [qw( user.* contact.* creator_id owner_id is_deleted contact.timezone.ofs )]
);

my $flattener= RapidApp::DBIC::RelationTreeFlattener->new(spec => $spec, ignoreUnexpected => 0);

my $treed= {
	creator_id => 5,
	owner_id => 7,
	is_deleted => 0,
	user => { username => 'foo', password => 'yes' },
	contact => {
		first => 'John',
		last => 'Doe',
		timezone => { ofs => -500 }
	},
};
my $flattened= {
	creator_id => 5,
	owner_id => 7,
	is_deleted => 0,
	user_username => 'foo',
	user_password => 'yes',
	contact_first => 'John',
	contact_last => 'Doe',
	contact_timezone_ofs => -500,
};
  
is_deeply( $flattener->flatten($treed), $flattened, 'flatten a tree' );
is_deeply( $flattener->restore($flattened), $treed, 'restore a tree' );

$db= FakeSchema->new({
	A => { columns => [qw[ b_id ]], rels => { b => 'B' } },
	B => { columns => [qw[ id ]], rels => { } },
});

# test case where column flat keyname is ambiguous
$spec= RapidApp::DBIC::RelationTreeSpec->new(
	source => $db->source('A'),
	colSpec => [qw( * b.* )]
);
ok do {
	try { RapidApp::DBIC::RelationTreeFlattener->new(spec => $spec, ignoreUnexpected => 0)->_colmap; 0 }
	catch { diag("Error: ".$_); $_ =~ /both map to the key/ }
	},
	'Error if keys clash';

$flattener= RapidApp::DBIC::RelationTreeFlattener->new(spec => $spec, ignoreUnexpected => 0, namingConvention => 'brief');
$treed= { b_id => 'foo', b => { id => 'bar' } };
$flattened= { c4b_id => 'foo', c1b2id => 'bar' };
is_deeply( $flattener->flatten($treed), $flattened, 'flatten using brief naming convention' );
is_deeply( $flattener->restore($flattened), $treed, 'restore using brief naming convention' );

done_testing;
