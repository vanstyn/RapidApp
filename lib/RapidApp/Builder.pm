package RapidApp::Builder;

use strict;
use warnings;

# ABSTRACT: Programmatic RapidApp instance builder

use Moose;
extends 'CatalystX::AppBuilder';

use Types::Standard qw(:all);
use RapidApp::Util ':all';

# Don't use any of the defaults from superclass:
sub _build_plugins {[]}

around 'plugins' => sub {
  my ($orig,$self,@args) = @_;

  my @plugins = ( 'RapidApp', @{ $self->$orig(@args) } );
  
  # Handle debug properly:
  unshift @plugins, '-Debug' if ($self->debug);

  [ uniq( @plugins ) ]
};

has '_bootstrap_called', is => 'rw', isa => Bool, default => sub {0}, init_arg => undef;
after 'bootstrap' => sub { (shift)->_bootstrap_called(1) };

sub ensure_bootstrapped {
  my $self = shift;
  $self->_bootstrap_called ? 1 : $self->bootstrap(@_)
}

has 'psgi_app', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  $self->ensure_bootstrapped(1);
  
  my $c = $self->appname;
  $c->apply_default_middlewares($c->psgi_app)
  
}, init_arg => undef;

sub to_app { (shift)->psgi_app }

1;

__END__

=head1 NAME

RapidApp::Builder - Programmatic RapidApp instance builder

=head1 SYNOPSIS

 use RapidApp::Builder;
 
 my $builder = RapidApp::Builder->new(
    debug  => 1, 
    appname => "My::App",
    plugins => [ ... ],
    config  => { ... }
 );

 # Plack app:
 $builder->to_app


=head1 DESCRIPTION

...

=head1 CONFIGURATION

=head2 plugins

...



=head1 METHODS

=head2 psgi_app

...

=head2 to_app

PSGI C<$app> CodeRef. Derives from L<Plack::Component>


=head1 SEE ALSO

=over

=item * 

L<RapidApp>

=back


=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


