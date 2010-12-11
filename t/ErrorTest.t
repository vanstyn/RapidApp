use strict;
use warnings;
use Test::More;
use Try::Tiny;
use Data::Dumper;

BEGIN {
	use_ok 'RapidApp::Error';
	use_ok 'RapidApp::Error::WrappedError';
	use_ok 'RapidApp::Error::UserError';
}

sub constructor {
	my $err;
	my $msg= 'We died';
	$err= new_ok('RapidApp::Error', [ $msg ], 'basic constructor');
	is($err->message, $msg);
	$err= new_ok('RapidApp::Error', [ message => $msg ], 'parameterized constructor');
	is($err->message, $msg);
	$err= new_ok('RapidApp::Error', [ message_fn => sub { (shift)->data->{foo} }, data => { foo => $msg } ], 'with lazy message');
	is($err->message, $msg);
	done_testing;
}

sub userErrorConstructor {
	my $err;
	my $msg= 'We died';
	$err= new_ok('RapidApp::Error::UserError', [ $msg ], 'basic constructor');
	is($err->message, $msg);
	is($err->userMessage, $msg);
	$err= new_ok('RapidApp::Error::UserError', [ message => $msg ], 'with message');
	is($err->message, $msg);
	is($err->userMessage, $msg);
	$err= new_ok('RapidApp::Error::UserError', [ userMessage => $msg ], 'with userMessage');
	is($err->message, $msg);
	is($err->userMessage, $msg);
	done_testing;
}

sub stringification {
	my $err;
	my $msg= 'We died';
	my $msgWithLocation= $msg.' at /path/to/some/file.pm line 64.';
	my $msgWithLocationContext= $msg.' at /path/to/some/file.pm line 64 near "literal
context
in source
file".';
	
	$err= RapidApp::Error->new($msg);
	is(''.$err, $msg, 'Error');
	
	$err= RapidApp::Error->new($msgWithLocation);
	is(''.$err, $msgWithLocation, 'Error with line info');
	
	$err= RapidApp::Error::WrappedError->new({ captured => $msg, lateTrace => 0 });
	is(''.$err, $msg, 'WrappedError');
	
	$err= RapidApp::Error::WrappedError->new({ captured => $msgWithLocation, lateTrace => 0});
	is(''.$err, $msgWithLocation, 'WrappedError with line info');
	
	$err= RapidApp::Error::UserError->new($msg);
	is(''.$err, $msg, 'UserError');
	
	$err= RapidApp::Error::UserError->new($msgWithLocation);
	is(''.$err, $msgWithLocation, 'UserError with line info');
	
	done_testing;
}

sub dieConversion {
	my $err;
	my $msg= 'We died';
	local $SIG{__DIE__}= \&RapidApp::Error::dieConverter;
	
	try { die $msg }
	catch {
		isa_ok($_, 'RapidApp::Error', 'text conversion');
		is($_->message, $msg, 'text captured as message');
		like(''.$_, qr/$msg at .* line .*/, 'original exception preserved when stringify');
	};
	
	try { die RapidApp::Error->new($msg) }
	catch {
		is(ref $_, 'RapidApp::Error', 'error passthrough');
	};
	
	try { die RapidApp::Error::UserError->new($msg) }
	catch {
		is(ref $_, 'RapidApp::Error::UserError', 'error passthrough 2');
	};
	
	try { die [ 1, 2, 3, 4, 5 ]; }
	catch {
		is(ref $_, 'ARRAY', 'non-blessed passthrough')
	};
	
	try { die bless { foo => 1, bar => 2 }, 'IckyIckyIckyPitang'; }
	catch {
		is(ref $_, 'IckyIckyIckyPitang', 'unknown passthrough')
	};
	
	done_testing;
}

sub foo {
	$_[0]->new($_[1]);
}
sub bar {
	foo(@_);
}
sub baz {
	bar(@_);
}
sub traceCollection {
	my $err;
	my $msg= 'Died Here';
	$err= baz('RapidApp::Error', { message => $msg });
	#diag(Dumper($err->trace->frame(0)));
	like($err->trace->frame(0)->subroutine, qr/RapidApp::Error::new/, 'first reported frame');
	like($err->trace->frame(1)->subroutine, qr/.*::foo/, 'second reported frame');
	
	done_testing;
}

subtest 'Constructor Tests' => \&constructor;
subtest 'User Error Constructor Tests' => \&userErrorConstructor;
subtest 'Stringification' => \&stringification;
subtest 'Die Conversion' => \&dieConversion;
subtest 'Trace Collection' => \&traceCollection;
done_testing;
