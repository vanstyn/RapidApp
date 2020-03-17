#!/usr/bin/env perl

use strict;

use RapidApp::Util::Rau;

if (!$ARGV[0] || $ARGV[0] eq '--help') {
  RapidApp::Util::Rau::usage();
  exit; # redundant
}

RapidApp::Util::Rau->argv_call();

1;

__END__

=head1 NAME

rau.pl - RapidApp umbrella utility script

=head1 SYNOPSIS

 rau.pl [MODULE] [options]

 Available Modules:
   * model-update

=head1 DESCRIPTION

C<rau.pl> is a multi-purpose utility script which comprises sub-modules that expose
misc functions on the command line. C<rau.pl> should be called with the first argument
containing the name of the module followed by its argument list which will be passed in
to the given module.

Call a module with the argument C<--help> to see its usage.

Module names are translated into CamelCased class named under the C<RapidApp::Util::Rau::*>
namespace. For example, C<'modal-update'> becomes C<'RapidApp::Util::Rau::ModelUpdate'>.

So far, the only module which has been written is L<RapidApp::Util::Rau::ModelUpdate>.


=head1 SEE ALSO

L<RapidApp>

=head1 SUPPORT

IRC:

    Join #rapidapp on irc.perl.org.

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.


=cut
