package RapidApp;
use strict;
use warnings;

# Min supported Perl is currently v5.10
use 5.010;

our $VERSION = 0.9999_04;

# ABSTRACT: Turnkey ajaxy webapps

use Time::HiRes qw(gettimeofday);
use File::ShareDir qw(dist_dir);

# For statistics:
our $START = [gettimeofday];

sub share_dir {
  my $class = shift || __PACKAGE__;
  return $ENV{RAPIDAPP_SHARE_DIR} || dist_dir($class);
}

# global variable localized with '$c' automatically to provide
# simple/global API access within all code dispatched by RapidApp
# to be able to identify if there is a current request, and if so
# get the $c object without fuss.
our $ACTIVE_REQUEST_CONTEXT = undef;

sub active_request_context { $ACTIVE_REQUEST_CONTEXT }



# Private - will be removed in the future:
our $ROOT_MODULE_INSTANCE = undef;
sub _rootModule { $ROOT_MODULE_INSTANCE }

1;


__END__

=pod

=head1 NAME

RapidApp - Turnkey ajaxy webapps

=head1 SYNOPSIS

See L<www.rapidapp.info|http://www.rapidapp.info> and L<RapidApp::Manual> for more information.

  # Create new app named "MyApp" using all the helpers:
  rapidapp.pl --helpers RapidDbic,Templates,TabGui,AuthCore,NavCore MyApp \
    -- --dsn dbi:mysql:database=somedb,root,''

  # Start the test server (default login admin/pass):
  MyApp/script/myapp_server.pl


  # OR, start up an instant database CRUD app/utility at http://localhost:3500/
  rdbic.pl dbi:mysql:database=somedb,root,''

=head1 DESCRIPTION

RapidApp is an extension to L<Catalyst> - the Perl MVC framework. It provides a feature-rich
extended development stack, as well as easy access to common out-of-the-box application paradigms, 
such as powerful CRUD-based front-ends for L<DBIx::Class> models, user access and authorization, 
RESTful URL navigation schemes, pure Ajax interfaces with no browser page loads, templating engine 
with front-side CMS features, declarative configuration layers, and more...

RapidApp is useful not only for new application development, but also for adding admin interfaces to 
existing applications, as well as for rapid prototyping.

Although RapidApp is based on Catalyst, fully encapsulated L<Plack> interfaces are also 
provided, such as L<Plack::App::RapidApp::rDbic>, which enables RapidApp to be integrated into
any application/framework which utilizes PSGI/Plack.

RapidApp started as an internal project in 2009 and has been under continuous development
ever since. It has been used very successfully for multiple medium to large-scale client 
applications (backends with hundreds of tables and tens of millions of rows) as well as 
many quick and easy apps and interfaces for smaller jobs.

We started open-sourcing RapidApp in 2013, and this work is ongoing...

RapidApp is built on top of a number of powerful open-source tools and technologies including:

=over

=item *

Perl

=item *

L<Catalyst>

=item *

L<DBIx::Class>

=item *

L<ExtJS|http://www.sencha.com>

=item *

L<Template::Toolkit>

=back

Documentation is still a work-in-progress. Much of it has been done, but much of it still
remains to be done: L<RapidApp::Manual>. 

Also, be sure to check out the RapidApp website for more information, including several 
comprehensive video demos and tutorials:

=over

=item *

L<www.rapidapp.info|http://www.rapidapp.info>

=back

=head1 SUPPORT
 
IRC:
 
    Join #rapidapp on irc.perl.org.

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut



