package DbicLinkComponent2;

use strict;
use warnings;
use Moose;
extends 'RapidApp::AppCmp';
with 'RapidApp::Role::DataStore2';
with 'RapidApp::Role::DbicLink';

use FakeSchema;

our $db= FakeSchema->new({
	A => { cols => [qw[ id a2 a3 a4 b_id ]], rels => { b => 'B' } },
	B => { cols => [qw[ id b2 b3 ]], rels => {} },
});

has '+no_rel_combos' => ( default => 1 );

sub _build_colSpec {
	[qw[ * b.* -b.id -a3 ]]
}

has ResultSource => ( is => 'ro', lazy_build => 1 );
sub _build_ResultSource {
	my $self = shift;
	return $db->source('A');
}

#------------------------------------------------------------------ test expectations

sub expected_ExtNamesToDbFields {
	{
		id => 'me.id',
		a2 => 'me.a2',
		a4 => 'me.a4',
		b_id => 'me.b_id',
		b_b2 => 'b.b2',
		b_b3 => 'b.b3',
	}
}

sub expected_joins {
	[ { b => {} } ]
}

1;