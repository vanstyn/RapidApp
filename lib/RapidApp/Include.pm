package RapidApp::Include;
use strict;
use warnings;

die join("\n",
  '','',
  '  ***  WARNING  ***',
  "  " . __PACKAGE__ . " is DEPRECATED. It has been replaced by consolidated 'RapidApp::Util' package",
  "   [tip]: run `upgr-rapidapp.pl path/to/lib/` to upgrade your code automatically...",
  '',''
);

1;
__END__



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
  no strict 'refs';
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
	calleruse qw(Carp carp croak confess cluck longmess shortmess);
}

sub rapidapp_base {
	calleruse 'RapidApp::Responder::UserError';
	calleruse 'RapidApp::Responder::CustomPrompt';
	calleruse 'RapidApp::Responder::InfoStatus';
	calleruse 'RapidApp::JSONFunc';
	calleruse 'RapidApp::JSON::MixedEncoder';
	calleruse 'RapidApp::JSON::RawJavascript';
	calleruse 'RapidApp::JSON::ScriptWithData';
	calleruse 'RapidApp::Functions';
}

sub sugar {
	calleruse 'RapidApp::Sugar';
}


1;