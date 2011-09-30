use strict;
use warnings;
use Test::More;
use Try::Tiny;
use Data::Dumper;
use Clone 'clone';

package TestClsA;
use Moose;

has 'x' => ( is => 'rw', default => 0 );
has 'y' => ( is => 'rw', default => 1 );
has 'z' => ( is => 'rw', default => 2 );

1;

package TestClsB;
use Moose;

has 'a' => ( is => 'rw', default => 'foo' );
has 'b' => ( is => 'rw', default => sub {{ 1 => 2 }} );
has 'c' => ( is => 'rw', default => sub {[qw[1 2 3 4 5 6 7]]} );

1;

package main;

BEGIN {
	use_ok 'RapidApp::Data::DeepMap';
}

sub default_behavior {
	my $mapper= RapidApp::Data::DeepMap->new();
	my $tests = [
		'simple hash' => { foo => 1, bar => 2, baz => 3 },
		'deep hash' => { foo => { bar => { baz => 3 } } },
		'simple array' => [ 1, 2, 3, 4, 5 ],
		'nested array' => [ [ [ [ [ 0 ] ], 1, 2, 3, 4, 5, 6, 7, 8, 9, [ 1, 2, 3, 4, 5 ], [ 3, 4, 5, 6, 7 ] ] ] ],
		'object' => TestClsA->new(),
		'combo' => TestClsA->new( x => { 1, 2, 3, 4, { a => 1, b => 2 }, TestClsA->new() } ),
	];
	for (my $i=0; $i < $#$tests; $i+=2) {
		my ($name, $hash)= ($tests->[$i], $tests->[$i+1]);
		my $mapped= $mapper->translate($hash);
		is_deeply($mapped, $hash, $name);
	}
	done_testing;
}

sub override_default {
	my $mapper = RapidApp::Data::DeepMap->new(
		defaultMapper => sub {
			my ($obj, $mapper)= @_;
			!ref $obj and return $obj+1;
			return RapidApp::Data::DeepMap::fn_translateContents(@_);
		}
	);
	my @tests = (
		'simple hash', { foo => 1, bar => 2, baz => 3 }, { foo => 2, bar => 3, baz => 4 },
		'deep hash',    { foo => { bar => { baz => 3 } } }, { foo => { bar => { baz => 4 } } },
		'simple array', [ 1, 2, 3, 4, 5 ], [ 2, 3, 4, 5, 6 ],
		'nested array', [ [ [ [ [ 0 ] ], 1, 2, 3, 4, 5, 6, 7, 8, 9, [ 1, 2, 3, 4, 5 ], [ 3, 4, 5, 6, 7 ] ] ] ],  [ [ [ [ [ 1 ] ], 2, 3, 4, 5, 6, 7, 8, 9, 10, [ 2, 3, 4, 5, 6 ], [ 4, 5, 6, 7, 8 ] ] ] ],
	);
	for (my $i=0; $i < $#tests; $i+= 3) {
		my ($name, $src, $dst)= @tests[$i..($i+2)];
		my $copy= clone($src);
		my $mapped=  $mapper->translate($src);
		
		is_deeply($mapped, $dst, $name);
		is_deeply($src, $copy, $name . ' (source unmodified)');
	}
	done_testing;
}

sub filter_by_ref {
	my @tests = (
		'Replace leaf object',
		{ a => 1, b => 2, c => 3, d => TestClsA->new(), x => TestClsB->new },
		{ a => 1, b => 2, c => 3, d => TestClsA->new(), x => '[TestClsB]' },
		
		'Don\'t descend into object',
		{ a => 1, b => 2, c => 3, d => TestClsA->new(x => TestClsB->new) },
		{ a => 1, b => 2, c => 3, d => TestClsA->new(x => TestClsB->new) },
		
		'Non-blessed',
		{ a => 1, b => 2, c => 3, d => sub { 1 } },
		{ a => 1, b => 2, c => 3, d => '[CODE]' },
	);
	
	my $mapper= RapidApp::Data::DeepMap->new(
		mapperByRef => {
			TestClsB => sub { '['.(ref $_[0]).']' },
			CODE => sub { '[CODE]' },
		}
	);
	for (my $i=0; $i < $#tests; $i+= 3) {
		my ($name, $src, $dst)= @tests[$i..($i+2)];
		my $copy= clone($src);
		my $mapped=  $mapper->translate($src);
		
		is_deeply($mapped, $dst, $name);
		is_deeply($src, $copy, $name . ' (source unmodified)');
	}
	done_testing;
}

sub one_xlate_per_instance {
	my $count= 0;
	my $mapper= RapidApp::Data::DeepMap->new(
		mapperByRef => {
			TestClsA => sub { $count++; return 1; }
		}
	);
	my $a= TestClsA->new();
	my $src= { a => $a, b => $a, c => $a, d => $a, e => { f => [ $a, $a ], g => $a } }; 
	my $dst= { a => 1, b => 1, c => 1, d => 1, e => { f => [ 1, 1 ], g => 1 } };
	my $mapped= $mapper->translate($src);
	is_deeply($mapped, $dst, 'mapped correctly');
	is($count, 1, 'xlate call count');
	done_testing;
}

subtest 'Default Behavior' => \&default_behavior;
subtest 'Custom default' => \&override_default;
subtest 'Filter By Ref' => \&filter_by_ref;
subtest 'One Translate Per Instance' => \&one_xlate_per_instance;
done_testing;
