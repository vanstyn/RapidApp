use strict;
use warnings;
use Test::More;
use Try::Tiny;
use Data::Dumper;
use Carp;
use Catalyst::Utils;
use Storable 'freeze', 'thaw';

BEGIN {
	use_ok 'RapidApp::Error';
	use_ok 'RapidApp::Error::WrappedError';
	use_ok 'RapidApp::Error::UserError';
}

{
	my $fname= __FILE__;
	$fname =~ s|/[^/]+$||;
	unshift @INC, $fname.'/../blib';
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
	like(''.$err, qr/$msg at [^ ]/, 'Error');
	
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

our $expectedCallDepth= 0;
sub fromRaw {
	$expectedCallDepth= 1;
	die "MyString";
}
sub fromDirect {
	$expectedCallDepth= 1;
	die RapidApp::Error->new("UniqueString4321");
}
sub fromCarp {
	$expectedCallDepth= 2;
	croak("UniqueString4321");
}
sub fromConfess {
	$expectedCallDepth= 2;
	confess("UniqueString4321");
}
sub fromUse {
	$expectedCallDepth= 1;
	require Nonexistent::Package::UniqueString4321;
}
sub fromUse2 {
	$expectedCallDepth= 1;
	require Package_Which_Cant_Compile;
}
sub fromCatalystUtilLoad {
	$expectedCallDepth= 3;
	Catalyst::Utils::ensure_class_loaded('Nonexistent::Package::UniqueString4321');
}
sub intermediate_method {
	&{$_[0]};
}

sub traceCollection {
	my $err;
	my $msg= 'Died Here';
	$err= foo('RapidApp::Error', { message => $msg });
	#diag(Dumper($err->trace->frame(0)));
	like($err->trace->frame(0)->subroutine, qr/RapidApp::Error::new/, 'first reported frame');
	like($err->trace->frame(1)->subroutine, qr/.*::foo/, 'second reported frame');
	
	my @fnList= qw( fromDirect fromCarp fromConfess fromUse fromUse2 fromCatalystUtilLoad);
	for my $fn (@fnList) {
		my $err;
		local $SIG{__DIE__}= \&RapidApp::Error::dieConverter;
		try { &intermediate_method(\&$fn) }
		catch { $err= RapidApp::Error::capture($_); };
		
		like("$err", qr/UniqueString4321/, $fn.' - message preserved');
		like("$err", qr/ErrorTest.t line [0-9]+/, $fn.' - line preserved');
		
		my @frames= $err->trace->frames;
		my $i;
		for ($i=0; $i <= $#frames; $i++) {
			last if $frames[$i]->subroutine =~ /intermediate_method/;
		}
		
		ok($i <= $#frames, $fn.' - trace preserved');
		is($i, $expectedCallDepth+1, $fn.' - trace starts at correct line');
	}
	
	done_testing;
}

sub dieInDeepStack {
	my $depth= shift;
	die RapidApp::Error->new("Deep exception") unless $depth;
	dieInDeepStack($depth-1, @_);
}

package BogusCatalystApp;
use Catalyst;

package main;

sub sizeCompaction {
	my $c= {};
	for (my $i=10000; $i >= 0; $i--) {
		$c->{$i}= "$i kljfhdhflsdkhflakjsdhflkasdjhflkjsdhflkajsdhflkasjdhflajksdhflaksdjhflkasjdhflkdsajhflkasdjhflaksdjhflaksjdhf";
	}
	bless $c, 'BogusCatalystApp';
	isa_ok($c, 'Catalyst');
	
	my $err;
	try {
		dieInDeepStack(50, $c);
	}
	catch {
		$err= $_;
		$err->data->{info}= $c;
	};
	
	local $Storable::forgive_me= 1; # ignore non-storable things
	my $serialized= freeze($err);
	ok(length($serialized) > 100000, 'object starts large ('.length($serialized).')');
	
	my $err2= $err->getTrimmedClone(50);
	$serialized= freeze($err2);
	ok(length($serialized) < 100000, 'trimmed object is small ('.length($serialized).')');
	
	#print STDERR Dumper($err2);
	
	done_testing;
}


subtest 'Constructor Tests' => \&constructor;
subtest 'User Error Constructor Tests' => \&userErrorConstructor;
subtest 'Stringification' => \&stringification;
subtest 'Die Conversion' => \&dieConversion;
subtest 'Trace Collection' => \&traceCollection;
subtest 'Size compaction' => \&sizeCompaction;
done_testing;
