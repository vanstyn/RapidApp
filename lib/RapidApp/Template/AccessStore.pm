package RapidApp::Template::AccessStore;
use strict;
use warnings;

use RapidApp::Util qw(:all);

use Moo;
extends 'RapidApp::Template::Access', 'RapidApp::Template::Store';


=pod

=head1 DESCRIPTION

Base class which combines both the Access and the Store class into a single class that performs
both functions. This is an Access class first, and when the Access class is also a Store, the
system will use it that way. This class exists just to give an easier API to be able to extend
this class if the AccessStore pattern is desired.

The AccessStore pattern was added after the optional Store class was added to be able to return
to the concept of a single class interface to be able to control template behavior, but without
forcing all Access classes to also be Stores, since this is only a marginal use-case, since Stores
are not required for basic function, only if the user wants to retreive tempaltes in some manner
beyond the file-system capabilities of RapidApp::Template::Provider.

=cut


1;