package RapidApp::ScopedGlobals;

use strict;
use warnings;

=head1 NAME

RapidApp::ScopedGlobals

=head1 SYNOPSIS

  use RapidApp::ScopedGlobals;
  sub foo_0 {
    RapidApp::ScopedGlobals->applyForSub({ x => 1 }, \&foo_1 );
  }
  sub foo_1 {
    RapidApp::ScopedGlobals->applyForSub({ x => 2 }, \&foo_2 );
    print RapidApp::ScopedGlobals->x;
  }
  sub foo_2 {
    print RapidApp::ScopedGlobals->x, ",";
  }
  
  # calling foo_0 prints "2,1"

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

=head1 METHODS

=cut

our $_vals= {};

=head2 applyForSub( \%,  \CODE )

Calls the given coderef with the given alterations of the "global" variables.  When the coderef
returns, the global values will revert to what they were before the call.  See perl's "local"
keyword for implementation details.

=cut
sub applyForSub {
	my ($class, $varChangeHash, $sub)= @_;
	$class eq __PACKAGE__ or die "applyForSub is a package method";
	ref $varChangeHash eq 'HASH' or die "Expected hash of variable alterations as first parameter";
	ref $sub eq 'CODE' or die "Expected coderef as second parameter";
	
	local $_vals= { %$_vals, %$varChangeHash };
	return $sub->();
}

=head2 varExists( $varName )

Returns true of the named global has been set by a parent function of the current call stack.

=cut
sub varExists {
	my ($class, $varName)= @_;
	return exists $_vals->{$varName};
}

=head2 get( $varName )

Returns the value of the named scoped-global, or undef if it has not been set.  Note that
a scoped-global could have been set to undef.  Use "varExists" to determine the difference.

=cut
sub get {
	my ($class, $varName)= @_;
	return $_vals->{$varName};
}

=head AUTOLOAD

RapidApp::ScopedGlobals defines an auto-loader that allows you to use any named global as if it
were a method.  If the global has not been defined in this call stack, an exception is thrown.
This allows better debugging of typo'd var names, but if you don't want an exception, use "get".

=cut
our $AUTOLOAD; # built-in package global
sub AUTOLOAD {
	my $vName= substr($AUTOLOAD, length(__PACKAGE__)+2);
	exists $_vals->{$vName} or die "ScopedGlobal $vName has not been defined in this call stack";
	return $_vals->{$vName};
}

1;