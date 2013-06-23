package RapidApp::JSON::MixedEncoder;

use strict;
use warnings;
use Scalar::Util 'blessed';
use Data::Dumper;
use base 'JSON::PP';

our @EXPORT = qw{encode_json decode_json encode_json_utf8 decode_json_utf8};

# copied from JSON::PP
my $JSON; # cache
sub encode_json ($) { # encode
	($JSON ||= __PACKAGE__->new)->encode($_[0]);
}
sub decode_json ($) { # decode
	($JSON ||= __PACKAGE__->new)->decode($_[0]);
}

my $JSONUtf8; # cache
sub encode_json_utf8 ($) { # encode
	($JSONUtf8 ||= __PACKAGE__->new->utf8)->encode($_[0]);
}
sub decode_json_utf8 ($) { # decode
	($JSONUtf8 ||= __PACKAGE__->new->utf8)->decode($_[0]);
}


sub new {
	return bless JSON::PP->new->allow_blessed->convert_blessed->allow_nonref, __PACKAGE__;
}


# We need to do this so that JSON won't quote the output of our
# TO_JSON method and will allow us to return invalid JSON...
# In this case, we're actually using the JSON lib to generate
# JavaScript (with functions), not JSON
sub object_to_json {
	my ($self, $obj)= @_;
  
  my $type = ref($obj);
    
  # Convert \'NULL' into undef (this came up after switing from MySQL to SQLite??)
  $obj = undef if ($type eq 'SCALAR' && $$obj eq 'NULL');
  
  # FIXME: This is another SQLite-ism: There are probably more
  $obj = undef if ($type eq 'SCALAR' && $$obj eq 'current_timestamp');
  
	if (blessed($obj)) {
		my $method= $obj->can('TO_JSON_RAW');
		return $method->($obj) if defined $method;
	}
  
  return $self->SUPER::object_to_json($obj);
}

1;