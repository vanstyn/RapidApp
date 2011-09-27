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

$SIG{__WARN__}= sub { diag("Warn: ", @_); };

sub test_flattener_from_joins {
	my $cmp= DbicLinkComponent1->new(module_name => 'DbicLinkComponent1', parent_module_ref => undef, module_path => '/', );
	ok($cmp, 'Component created');
	my $f= $cmp->relationTreeFlattener();
	ok($f, 'Flattener created');
	is_deeply( $f->spec->colTree, { foo_bar => 1 }, 'Correct columns created');
}

RapidApp::ScopedGlobals->applyForSub(
	{ catalystClass => 'FakeApp', log => bless( {}, 'LogToDiag')},
	sub {
		RapidApp::TraceCapture::saveExceptionsDuringCall(
			sub {
				subtest 'Flattener from Joins' => \&test_flattener_from_joins;
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
