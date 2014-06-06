package RapidApp::JSON::ScriptWithData;

use strict;
use warnings;
use Scalar::Util;
use RapidApp::JSON::MixedEncoder 'encode_json';

=head1 NAME

RapidApp::JSON::ScriptWithData

=head1 SYNOPSIS

  use RapidApp::JSON::ScriptWithData;
  use RapidApp::JSON::MixedEncoder 'encode_json';
  
  $swd= RapidApp::JSON::ScriptWithData->new(
    'function () {',
      'blah(12345);',
      'var b= foo(bar(', $self->getSomething, '));',
      'var a=', { x=>1, y=>2, z=>3 }, ';',
      'return baz(a, b);',
    '}'
  );
  
  return encode_json($swd);

=cut

sub new {
	my ($class, @args)= @_;
	return bless \@args, $class;
}

sub TO_JSON_RAW {
	my $self= shift;
	return join '', (map { ref $_? encode_json($_) : $_ } @$self);
}

1;