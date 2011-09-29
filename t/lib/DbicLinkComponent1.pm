package DbicLinkComponent1;

use strict;
use warnings;
use Moose;
extends 'RapidApp::AppCmp';
with 'RapidApp::Role::DataStore2';
with 'RapidApp::Role::DbicLink';

use FakeSchema;

our $db= FakeSchema->new({
	A   => { cols => [qw[ id foo_bar ]], rels => { foo => 'Foo' } },
	Foo => { cols => [qw[ bar ]], rels => {} },
});

has '+no_rel_combos' => ( default => 1 );

has 'joins' => ( is => 'ro', lazy_build => 1 );
sub _build_joins { 
	[
		'foo',
	]
}

has ResultSource => ( is => 'ro', lazy_build => 1 );
sub _build_ResultSource {
	my $self = shift;
	return $db->source('A');
}

1;