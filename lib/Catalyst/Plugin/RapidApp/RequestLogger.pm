package Catalyst::Plugin::RapidApp::RequestLogger;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp';

# Plugin logs all requests to CoreSchema

use RapidApp::Util qw(:all);
require Module::Runtime;
require Catalyst::Utils;
use CatalystX::InjectComponent;

use Time::HiRes qw(gettimeofday tv_interval);


after 'setup_components' => sub {
  my $c = shift;

  # This same model/schema is used by AuthCore:
  CatalystX::InjectComponent->inject(
    into => $c,
    component => 'Catalyst::Model::RapidApp::CoreSchema',
    as => 'Model::RapidApp::CoreSchema'
  ) unless ($c->model('RapidApp::CoreSchema'));

};

before 'dispatch' => sub {
  my $c = shift;
  $c->model('RapidApp::CoreSchema::Request')->record_ctx_Request($c);
  1;
};

1;

__END__

=head1 NAME

Catalyst::Plugin::RapidApp::RequestLogger - Log all requests to the CoreSchema

=head1 SYNOPSIS

 package MyApp;

 use Catalyst   qw/
   RapidApp::RequestLogger
 /;

=head1 DESCRIPTION

Experimental plugin records every Catalyst request to a table in the
L<Model::RapidApp::CoreSchema|Catalyst::Model::RapidApp::CoreSchema>.
This will obviously slow down the app.

This plugin is just experimental and not well supported - do not use in production.

=head1 SEE ALSO

=over

=item *

L<RapidApp::Manual::Plugins>

=item *

L<Catalyst::Plugin::RapidApp::CoreSchema>


=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


1;


