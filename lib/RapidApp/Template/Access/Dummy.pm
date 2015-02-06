package RapidApp::Template::Access::Dummy;
use strict;
use warnings;

use RapidApp::Util qw(:all);

use Moo;
use Types::Standard qw(:all);

=pod

=head1 DESCRIPTION

Dummy Access class which provides open access

=cut

extends 'RapidApp::Template::Access';

# Simple bool permission methods:

sub template_viewable       { 1 }
sub template_readable       { 1 }
sub template_writable       { 1 }
sub template_creatable      { 1 }
sub template_deletable      { 1 }
sub template_admin_tpl      { 1 }
sub template_non_admin_tpl  { 0 }
sub template_external_tpl   { 0 }


1;