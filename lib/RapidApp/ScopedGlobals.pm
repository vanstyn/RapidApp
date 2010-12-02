package RapidApp::ScopedGlobals;

use strict;
use warnings;

=head1 NAME

RapidApp::ScopedGlobals

=head1 DESCRIPTION

This ScopedGlobals package implements a type of "constant environment" global.  No code may
modify the value of the global for its current scope, but it may redefine a global for the scope
of a sub-method (often an anonymous sub).

By using globals this way, they become much more like environment variables in nested shell
scripts.  It limits "spooky action from a distance" because no routine can modify its parents'
variables (though unfortunately it is still possible to modify the deep contents of a hash
which could be seen by a parent).  Instead, they act much more like invisible parameters to a
method, which can help when working with frameworks where it is impossible or just inconvenient
to pass those parameters to an inner module or method.

=cut

our $_vals= {};

sub applyForSub {
	my ($class, $varChangeHash, $sub)= @_;
	$class eq __PACKAGE__ or die "applyForSub is a package method";
	ref $varChangeHash eq 'HASH' or die "Expected hash of variable alterations as first parameter";
	ref $sub eq 'CODE' or die "Expected coderef as second parameter";
	
	local $_vals= { %$_vals, %$varChangeHash };
	return $sub->();
}

our $AUTOLOAD; # built-in package global
sub AUTOLOAD {
	my $vName= substr($AUTOLOAD, length(__PACKAGE__)+2);
	exists $_vals->{$vName} or die "ScopedGlobal $vName has not been defined in this call stack";
	return $_vals->{$vName};
}

1;