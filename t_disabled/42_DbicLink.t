#! /usr/bin/perl

use strict;
use warnings;
use Test::More;
use RapidApp::TraceCapture;
use RapidApp::ScopedGlobals;
use RapidApp::Debug 'DEBUG';

use lib 't/lib';
use FakeApp;
use FakeSchema;
use_ok 'DbicLinkComponent1';
use_ok 'DbicLinkComponent2';

$SIG{__WARN__}= sub { diag("Warn: ", @_); };

sub test_flattener_from_joins {
	my $cmp= DbicLinkComponent1->new(module_name => 'DbicLinkComponent1', parent_module_ref => undef, module_path => '/', );
	ok($cmp, 'Component created');
	my $f= $cmp->dbiclink_columns_flattener();
	ok($f, 'Flattener created');
	is_deeply( $f->spec->colTree, { foo_bar => 1, id => 1}, 'Correct columns created');
}

sub test_dbicquery {
	my $cmp= DbicLinkComponent2->new(module_name => 'DbicLinkComponent2', parent_module_ref => undef, module_path => '/', );
	ok($cmp, 'Component created');
	my $f= $cmp->dbiclink_columns_flattener();
	ok($cmp->DbicExtQuery, 'Created DbicExtQuery');
	is_deeply($cmp->DbicExtQuery->ExtNamesToDbFields, $cmp->expected_ExtNamesToDbFields, 'ExtNamesToDbFields');
	is_deeply($cmp->DbicExtQuery->joins, $cmp->expected_joins, 'joins');
}

RapidApp::ScopedGlobals->applyForSub(
	{ catalystClass => 'FakeApp', log => bless( {}, 'LogToDiag')},
	sub {
		RapidApp::TraceCapture::saveExceptionsDuringCall(
			sub {
				subtest 'Flattener from Joins' => \&test_flattener_from_joins;
				subtest 'DbicExtQuery Creation' => \&test_dbicquery;
				done_testing;
			}
		)
	}
);

package LogToDiag;
use Test::More;
sub fatal { diag('Fatal: ',@_[1..$#_]); }
sub error { diag('Error: ',@_[1..$#_]); }
sub warn { diag('Warn: ',@_[1..$#_]); }
sub info { diag('Info: ',@_[1..$#_]); }
sub debug { diag('Debug: ',@_[1..$#_]); }
