package RapidApp::View::Template;

use strict;
use warnings;

use base 'Catalyst::View';

use RapidApp::Include qw(sugar perlutil);


sub process {
  my ($self, $c)= @_;
  my $template = $c->stash->{template} or die "No template specified";
  $c->stash->{is_external_template}{$template} = 1 unless ($c->is_ra_ajax_req);
  $c->template_controller->view($c,$template);
}


1;


__END__

=head1 NAME

RapidApp::View::Template - Thin wrapper to dispatch to Template::Controller

=head1 DESCRIPTION

This is just a View interface to the Template::Controller system.

=head1 SEE ALSO

=over

=item *

L<RapidApp::Manual::Modules>

=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
