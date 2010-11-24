package RapidApp::JSON::RawJavascript;

use strict;
use warnings;
use Moose;

has 'js' => ( is => 'rw', isa => 'Str' );

around BUILDARGS => sub {
	my $orig= shift;
	my $class= shift;
	if (scalar(@_) == 1 && !ref $_[0]) {
		return $class->$orig( js => $_[0] ); # interpret single-param as a javascript fragment
	} else {
		return $class->$orig(@_);
	}
};

sub TO_JSON_RAW {
	return (shift)->js;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;