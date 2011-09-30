#! /usr/bin/perl

# PERLLIB=lib perl -MCarp=verbose t/RelationTreeSpec.t

use strict;
use Test::More;
use Try::Tiny;

use lib 't/lib';
use FakeSchema;
my $db= FakeSchema->new({
	A => bless({ columns => [qw[ a_id b_id c_id foo bar baz ]], rels => { b => 'B', c => 'C' } }),
	B => bless({ columns => [qw[ b_id c_id xx yy zz ]], rels => { c => 'C' } }),
	C => bless({ columns => [qw[ c_id a_id d_id blah blah2 blah3 ]], rels => { a => 'A', d => 'D' } }),
	D => bless({ columns => [qw[ col1 col2 col3 col4 col5 ]], rels => {} }),
});

use_ok('RapidApp::DBIC::RelationTreeSpec');

sub test_spec {
	sub validateSpec { RapidApp::DBIC::RelationTreeSpec->validateSpec(@_) }
	
	my @spec= qw( b c * -baz b.c.a.c.d.* b.* c.* b.c.* -b.c.blah2 -b.c.blah3 );

	ok validateSpec(\@spec), 'valid spec works';

	ok validateSpec([]), 'empty spec works';

	ok do { try { validateSpec([' ']); 0 } catch { 1; } }, 'invalid spec throws error';
	done_testing;
}

sub test_resolve {
	sub resolveSpecA { RapidApp::DBIC::RelationTreeSpec->resolveSpec($db->source('A'), [ @_ ]) }
	
	is_deeply(
		resolveSpecA(qw[ foo bar baz ]),
		{ foo => 1, bar => 1, baz => 1 },
		'simple list of columns');
	
	is_deeply(
		resolveSpecA(qw[ * ]),
		{ map { $_ => 1 } $db->source('A')->columns },
		'wildcard');
	
	is_deeply(
		resolveSpecA(qw( b.c.a.c.d.col4 )),
		{ b => { c => { a => { c => { d => { col4 => 1 } } } } } },
		'one very deep column');
	
	is_deeply(
		resolveSpecA(qw( b.* -b.xx )),
		{ b => { map { $_ => 1 } grep { $_ ne 'xx' } $db->source('B')->columns } },
		'wildcard and exclusion');
	
	is_deeply(
		resolveSpecA(qw( foo b.xx -b.xx )),
		{ foo => 1 },
		'eliminate unneeded relations');
	
	ok do { try { resolveSpecA(qw( y )); 0 } catch { 1; } }, 'invalid column throws error';
	ok do { try { validateSpec(qw( b.c.y )); 0 } catch { 1; } }, 'invalid relationship throws error';
	ok do { try { validateSpec(qw( b.xx.xx )); 0 } catch { 1; } }, 'invalid col used as rel throws error';
	
	done_testing;
}

sub test_relTree {
	sub specA { RapidApp::DBIC::RelationTreeSpec->new(source => $db->source('A'), colSpec => [ @_ ]) }
	
	is_deeply(
		specA(qw[ b.c.blah c.d.col5 ])->relTree,
		{ b => { c => {} }, c => { d => {} } },
		'double nested join');
}

sub test_union {
	sub unionA { RapidApp::DBIC::RelationTreeSpec->new(source => $db->source('A'), colSpec => $_[0])->union($_[1])->colTree }
	
	is_deeply(
		unionA( [qw[ a_id b_id foo bar ]], [qw[ c_id baz ]] ),
		{ map { $_ => 1 } qw( a_id b_id c_id foo bar baz ) },
		'no collisions');
	
	is_deeply(
		unionA( [qw[ a_id b_id c_id ]], [qw[ c_id foo a_id ]] ),
		{ map { $_ => 1 } qw( a_id b_id c_id foo ) },
		'top-level collisions');
	
	is_deeply(
		unionA( [qw[ b_id b.xx b.yy b.c.blah ]], [qw[ b.c.a.foo c_id b.c.blah ]] ),
		{ b_id=>1, c_id=>1, b => { xx=>1, yy=>1, c => { blah => 1, a => { foo=>1 } } } },
		'deep collisions');
}

sub test_intersect {
	sub intersectA { RapidApp::DBIC::RelationTreeSpec->new(source => $db->source('A'), colSpec => $_[0])->intersect($_[1])->colTree }
	
	is_deeply(
		intersectA( [qw[ a_id b_id c_id foo bar ]], [qw[ b_id foo baz ]] ),
		{ map { $_ => 1 } qw( b_id foo ) },
		'shallow');
	
	is_deeply(
		intersectA( [qw[ foo b.xx b.yy b.c.blah b.c.blah2 b.c.blah3 ]], [qw[ b.xx b.yy b.zz b.c.blah b.c.blah2 ]] ),
		{ b=>{ xx=>1, yy=>1, c=>{ blah=>1, blah2=>1 }}},
		'deep');
	
	is_deeply(
		intersectA( [qw[ b.c.blah c.blah3 ]], [qw[ c.blah b.c.blah2 ]] ),
		{},
		'eliminate unused relations');
}

sub test_subtract {
	sub subtractA { RapidApp::DBIC::RelationTreeSpec->new(source => $db->source('A'), colSpec => $_[0])->subtract($_[1])->colTree }
	
	is_deeply(
		subtractA( [qw[ a_id b_id c_id foo bar ]], [qw[ b_id foo ]] ),
		{ map { $_ => 1 } qw( a_id c_id bar ) },
		'one level deep');
	
	is_deeply(
		subtractA( [qw[ b.c.d.col1 baz ]], [qw[ b.c.d.col1 foo ]] ),
		{ baz => 1 },
		'eliminate unused relations');
	
	is_deeply(
		subtractA( [qw[ c.a.foo c.d.* b.c.d.* foo bar ]], [qw[ b.c.d.* foo c.a.foo bar c.d.* ]] ),
		{},
		'total negation');
}

subtest 'Spec Validity' => \&test_spec;
subtest 'Resolve Correctness' => \&test_resolve;
subtest 'Relation Tree' => \&test_relTree;
subtest 'Union' => \&test_union;
subtest 'Intersect' => \&test_intersect;
subtest 'Subtract' => \&test_subtract;
done_testing;

1;