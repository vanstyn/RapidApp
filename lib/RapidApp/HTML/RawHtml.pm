package RapidApp::HTML::RawHtml;
use strict;
use warnings;

use overload '""' => \&_stringify_static; # to-string operator overload

sub new {
	my ($class, $html)= @_;
	return bless \$html, $class;
}

sub _stringify_static {
	my $self= shift;
	$$self;
}

1;