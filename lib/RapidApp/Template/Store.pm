package RapidApp::Template::Store;
use strict;
use warnings;
use autodie;

use RapidApp::Util qw(:all);

use Moo;
use Types::Standard ':all';


=pod

=head1 DESCRIPTION

Base Template Store class which can be extended to provide an additional/different method
to provide template content. This class is separate from the Provider class in order to
supply a more simple API which consists of nothing but returning I/O associated
with a template name. While this is the job of the original Template::Provider from
the native Template::Toolkit, RapidApp::Template::Provider already extends the original
concept beyond simple template fetching, which justifies the need for this additional layer.

=cut

# reference to the Provider object is available if needed
has 'Provider', is => 'ro', required => 1;

# Base class owns no templates by default
has 'owned_tpl_regex', is => 'ro', isa => Maybe[Str], default => sub {undef};


# Compiled regex:
has '_owned_tpl_regexp', is => 'ro', lazy => 1, default => sub {
  my $str = (shift)->owned_tpl_regex or return undef;
  return qr/$str/;
}, isa => Maybe[RegexpRef];


sub owns_tpl {
  my ($self, $name) = @_;
  my $re = $self->_owned_tpl_regexp or return 0;
  $name =~ $re

}


sub template_exists   { die "Unimplemented" }
sub template_mtime    { die "Unimplemented" }
sub template_content  { die "Unimplemented" }
sub create_template   { die "Unimplemented" }
sub update_template   { die "Unimplemented" }
sub delete_template   { die "Unimplemented" }
sub list_templates    {[]}







1;
