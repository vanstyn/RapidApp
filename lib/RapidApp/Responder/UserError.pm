package RapidApp::Responder::UserError;

use Moose;
extends 'RapidApp::Responder';

use overload '""' => \&_stringify_static, fallback => 1; # to-string operator overload
use HTML::Entities;

=head1 NAME

RapidApp::Responder::UserError

=head1 DESCRIPTION

This "responder" takes advantage of the existing error-displaying codepaths
in RapidApp to (possibly) interrupt the current AJAX request and display the
message to the user.

See RapidApp::Sugar for the "die usererr" syntax.

See RapidApp::View::JSON for the logic this module ties into.

=cut

# Note that this is considered text, unless it is an instance of RapidApp::HTML::RawHtml
has userMessage      => ( is => 'rw', isa => 'Str|Object', required => 1 );
sub isHtml { return (ref (shift)->userMessage)->isa('RapidApp::HTML::RawHtml'); }

# same for the title
has userMessageTitle => ( is => 'rw', isa => 'Str|Object' );

sub writeResponse {
  my ($self, $c)= @_;

  $c->stash->{exception} = $self;
  $c->forward('View::RapidApp::JSON');
}

sub stringify { (shift)->userMessage }

# This method exists because 'overload' doesn't do dynamic method dispatch
# We use a named method (rather than overload '""' => sub { ... }) to improve
#   readibility of stack traces.
sub _stringify_static { (shift)->stringify }

no Moose;
__PACKAGE__->meta->make_immutable;
1;
