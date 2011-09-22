#! /usr/bin/perl

package FakeSource;

our %sources= (
	A => bless({ columns => [qw[ a_id b_id c_id foo bar baz ]], rels => { b => 'B', c => 'C' } }),
	B => bless({ columns => [qw[ b_id c_id xx yy zz ]], rels => { c => 'C' } }),
	C => bless({ columns => [qw[ c_id a_id d_id blah blah2 blah3 ]], rels => { a => 'A', d => 'D' } }),
	D => bless({ columns => [qw[ col1 col2 col3 col4 col5 ]], rels => {} }),
);

sub columns {
	@{ $_[0]->{columns} }
}
sub has_relationship {
	$_[0]->{rels}->{$_[1]}
}
sub related_source {
	my $srcN= $_[0]->{rels}->{$_[1]};
	$sources{$srcN};
}

package main;
use strict;
use Test::More;
use Try::Tiny;

use_ok('RapidApp::DBIC::RelationTreeSpec');

sub newspec { RapidApp::DBIC::RelationTreeSpec->new(@_) }

sub test_spec {
	my @spec= qw( b c * -baz b.c.a.c.d.* b.* c.* b.c.* -b.c.blah2 -b.c.blah3 );

	ok newspec(colSpec => \@spec), 'valid spec works';

	ok newspec(colSpec => []), 'empty spec works';

	ok do { try { newspec(colSpec => [' ']); 0 } catch { 1; } }, 'invalid spec throws error';
	done_testing;
}

sub test_resolve {
	sub resolveSpecA { RapidApp::DBIC::RelationTreeSpec->new(colSpec => [@_], source => $FakeSource::sources{A})->relationTree }
	
	is_deeply(
		resolveSpecA(qw[ foo bar baz ]),
		{ foo => 1, bar => 1, baz => 1 },
		'simple list of columns');
	
	is_deeply(
		resolveSpecA(qw[ * ]),
		{ map { $_ => 1 } $FakeSource::sources{A}->columns },
		'wildcard');
	
	is_deeply(
		resolveSpecA(qw( b.c.a.c.d.col4 )),
		{ b => { c => { a => { c => { d => { col4 => 1 } } } } } },
		'one very deep column');
	
	is_deeply(
		resolveSpecA(qw( b.* -b.xx )),
		{ b => { map { $_ => 1 } grep { $_ ne 'xx' } $FakeSource::sources{B}->columns } },
		'wildcard and exclusion');
	
	done_testing;
}

subtest 'Spec Validity' => \&test_spec;
subtest 'Resolve Correctness' => \&test_resolve;
done_testing;

1;