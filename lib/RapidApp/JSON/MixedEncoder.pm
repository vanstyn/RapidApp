package RapidApp::JSON::MixedEncoder;

use strict;
use warnings;
use Scalar::Util 'blessed';
use Data::Dumper;
use base 'JSON::PP';

@RapidApp::JSON::MixedEncoder::EXPORT = qw{encode_json decode_json};

# copied from JSON::PP
my $JSON; # cache
sub encode_json ($) { # encode
	($JSON ||= __PACKAGE__->new)->encode($_[0]);
}
sub decode_json ($) { # decode
	($JSON ||= __PACKAGE__->new)->decode($_[0]);
}

sub new {
	return bless JSON::PP->new->utf8->allow_blessed->convert_blessed, __PACKAGE__;
}

sub object_to_json {
	my ($self, $obj)= @_;
	if (blessed($obj)) {
		my $method= $obj->can('TO_JSON_RAW');
		return $method->($obj) if defined $method;
	}
	return $self->SUPER::object_to_json($obj);
}

1;