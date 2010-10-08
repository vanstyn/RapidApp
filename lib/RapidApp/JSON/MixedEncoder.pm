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
	($JSON ||= __PACKAGE__->new->utf8->allow_blessed)->encode($_[0]);
}
sub decode_json ($) { # decode
	($JSON ||= __PACKAGE__->new->utf8->allow_blessed)->decode($_[0]);
}

sub object_to_json {
	my ($self, $obj)= @_;
	return (blessed($obj) && $obj->can('TO_JSON_RAW'))? $obj->TO_JSON_RAW : $self->SUPER::object_to_json($obj);
}

1;