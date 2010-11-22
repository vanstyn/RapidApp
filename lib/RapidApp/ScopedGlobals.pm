package RapidApp::ScopedGlobals;

use strict;
use warnings;

=pod
	note: To make sure that we don't suffer the "bad aspects" of globals, always assign values
	to these variables using "local".
	example:
		use RapidApp::Globals;
		sub MyMethod {
			local $Log= SpecialLogger->new(params);
			$someObj->methodThatUsesLog();
		}
=cut

our $CatalystInstance= undef;
our $Log= undef;

sub catalystInstance {
	return $CatalystInstance;
}

sub log {
	return $Log;
}

1;