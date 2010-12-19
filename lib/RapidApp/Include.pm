package RapidApp::Include;

=head1 NAME

RapidApp::Include

=head1 SYNOPSIS

  # pulls in basic RapidApp parts
  use RapidApp::Include;
  
  # pulls in basic RapidApp parts, plus useful perl utils,
  #  extjs generators, and sugar methods
  use RapidApp::Include qw(perlutil extjs sugar);

=head1 DESCRIPTION

This module includes all the commonly-needed rapidapp classes.  It can pull in additional sets of
packages based on named sets, like "extjs" or "sugar".  The packages are imported directly into
the caller's namespace, as if they had been "use"d directly.

There is also a "perlutil" group for extremely common perl modules that we always use.

=head1 EXTENSION

To extend this module, simply create a function for each group you wish to be available,
and in the group, make calls to 'calleruse' to cause the use to happen within the calling
package.

=head1 SEE ALSO

L<Exporter>

L<Exporter::Cluster> (which was extremely useful as an example, but too simple to bother installing as a system package)

=cut

our $CALLER;
our $USEARGS;

sub import {
	my $class= shift;
	local $CALLER = caller;
	&$_ foreach (@_);
	rapidapp_base();
}

sub calleruse {
	my ($usePkg, @usePkgArgs)= @_;
	local $USEARGS= \@usePkgArgs;
	my $ret= eval "require $usePkg; package $CALLER; $usePkg->import( ".'@$'.__PACKAGE__."::USEARGS ); 1;";
	defined $ret or die $@;
}

sub perlutil {
	calleruse 'strict';
	calleruse 'warnings';
	calleruse qw(Scalar::Util blessed weaken reftype);
	calleruse 'Data::Dumper';
	calleruse 'Try::Tiny';
	calleruse 'DateTime';
	calleruse qw(Term::ANSIColor :constants);
	calleruse 'Clone';
	calleruse 'Hash::Merge';
}

sub rapidapp_base {
	calleruse 'RapidApp::Error';
	calleruse 'RapidApp::Error::UserError';
	calleruse 'RapidApp::ScopedGlobals';
	calleruse 'RapidApp::JSONFunc';
	calleruse 'RapidApp::JSON::MixedEncoder';
	calleruse 'RapidApp::JSON::RawJavascript';
	calleruse 'RapidApp::DbicExtQuery';
}

sub extjs {
	calleruse 'RapidApp::ExtJS::StaticCombo';
	# we will likely want to add a bunch more here, but I don't know which ones are in common use
}

sub sugar {
	calleruse 'RapidApp::Sugar';
}

1;