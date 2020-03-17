package Catalyst::Plugin::RapidApp::AuthCore::PlugHook;
use Moose::Role;
use namespace::autoclean;

use RapidApp::Util qw(:all);

=pod

=head1 DESCRIPTION

Plugin class seprated out of Catalyst::Plugin::RapidApp::AuthCore so
it can be loaded as a *plugin* (not a role) **AFTER** the other
required Authentication and Session plugins. This is needed to overcome
load ordering issues. 'finalize_session' below doesn't exist until
these plugins are loaded, and since AuthCore handles loading them, it
can't also define the around (chickin/egg issue)

=cut


# ---- FIXME  FIXME  FIXME (2013-08-25 by HV) ----
#
# The sole purpose of this class is to make session extending (expires)
# work. This is supposed to happen automatically, and does if the Auth/Session
# plugins are loaded in the manner intended in the main app class:
#
#   use Catalyst qw(
#     Authentication
#     Authorization::Roles
#     Session
#     Session::State::Cookie
#     Session::Store::DBIC
#   );
#
# Or later in:
#
#   __PACKAGE__->setup(qw(
#     Authentication
#     Authorization::Roles
#     Session
#     Session::State::Cookie
#     Session::Store::DBIC
#   ));
#
# However, for RapidApp, we obviously don't want the end developer to have to do
# that. We want them to just do:
#
#   with 'Catalyst::Plugin::RapidApp::AuthCore';
#
# and have it handle loading these plugins... This has been a struggle to
# get to work right. AuthCore handles loading the plugins 'before'
# $c->setup_dispatcher() because that is what is called immediately after
# $c->setup_plugins() in Catalyst.pm, and so it should be the earliest
# place to do it and have it work the same if AuthCore is loaded as a role
# using 'with' or loaded using the older use Catalyst @plg/__PACKAGE__->setup(@plg)
# syntax... (since everything before that point is before the plugin is loaded).
#
# It is not that I want to load it at this point, it is just that this is the
# best point I have found to do it -- Is there some totally different place
# or way to do this?
#
# It seems to work... ***almost***  ... Something is not quite right with the
# resulting state, the example being the broken extending of sessions which I
# am manually addressing below. Everything else seems to work and I don't know
# why or where or how things end up different. I have tried lots of other
# hook locations, like overriding '$c->arguments' and manually pushing the
# plugin list into it, (which works only for loading using 'with', but it is
# still broken in the same way).

# I don't understand the problem. It appears that certain methods just don't
# exist and/or don't get called. I've dumped mro::get_linear_isa($c) and it
# appears to come out the same, so I don't understand why that would be. I
# still don't fully undertand all the mro/MI/setup that works under the hood,
# and I think that is what is keeping me from figuring things out.
#
# Here is an example of my lack of understanding, and what I think is related
# to the problem:
#
# If I try to use a normal sub with next::method, instead of 'around' below,
# this gets thrown:
#  Caught exception in engine "No next::method 'finalize_session' found for ...
#
# Could it have to do with mixing method overrides with around and next::method
# style? It looks like the point where it might break, in following the Auth/Session
# plugins code, which seem to point back and forth at eachother in a maze, is that many
# methods, such as 'extend_session_id', return with maybe::next::method, which
# might explain the silently broken functionality, but still not *why* that is...
#
# I am putting this on the shelf for now, since I have a workaround below for this
# particular problem, but I am very concerned that my lack of understanding of these
# internals could be leading to other, deep, dark broken things that just haven't
# been noticed...

around 'finalize_session' => sub {
  my $orig = shift;
  my $c = shift;

  if($c->_user) {
    my $expires = $c->session_expires;
    my $sid = $c->sessionid;
    $c->store_session_data( "expires:$sid" => $expires );
  }

  $c->$orig(@_);
};

1;

