package RapidApp::HTML::RawHtml;
use strict;
use warnings;

=head1 NAME

RawHtml

=head1 DESCRIPTION

This miniature class is used to flag a scalar as containing text/html.

This should be used anywhere that you want to allow the API user to write direct
HTML, but want to provide the convenience of letting them just specify plaintext
for most cases.  To process it, just check whether the string isa("RapidApp::HTML::RawHtml")
before deciding whether to call escape_entities on the string.

You can use the sugar method "ashtml" (RapidApp::Sugar.pm) to make this conversion for you.

There is also a convenient sugar method "rawhtml".

=cut

use overload '""' => \&_stringify_static, fallback => 1; # to-string operator overload

sub new {
	my ($class, $html)= @_;
	return bless \$html, $class;
}

sub stringify { ${(shift)} }

# This method exists because 'overload' doesn't do dynamic method dispatch
# We use a named method (rather than overload '""' => sub { ... }) to improve
#   readibility of stack traces.
sub _stringify_static { (shift)->stringify }

1;