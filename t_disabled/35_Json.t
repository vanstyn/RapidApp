use strict;
use warnings;
use Test::More;
use Try::Tiny;
use Data::Dumper;
use Clone 'clone';

BEGIN {
	use_ok 'RapidApp::JSON::MixedEncoder';
	use_ok 'RapidApp::JSON::ScriptWithData';
}

sub script_with_data {
	my $swd= new_ok('RapidApp::JSON::ScriptWithData', [ "var x=", { a=>1, b=>2, c=>3 }, ";" ], 'create ScriptWithData');
	my $expectedJS= 'var x={"c":3,"a":1,"b":2};';
	is(encode_json($swd), $expectedJS, 'encode ScriptWithData');
	done_testing;
}

subtest 'ScriptWithData' => \&script_with_data;
done_testing;
