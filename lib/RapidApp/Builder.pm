package RapidApp::Builder;

use strict;
use warnings;

# ABSTRACT: Programmatic RapidApp instance builder

use Moo;
extends qw/ Plack::Component CatalystX::AppBuilder /;

use Types::Standard qw(:all);
use Class::Load 'is_class_loaded';
require Module::Locate; 

use RapidApp::Util ':all';

has 'base_appname', is => 'ro', isa => Maybe[Str], default => sub { undef };

has 'appname', is => 'ro', isa => Str, lazy => 1, default => sub {
  my $self = shift;
  my $base = $self->base_appname or die "Must supply either 'appname' or 'base_appname'";

  my ($class, $i) = ($base,0);
  
  # Aggressively ensure the class name is not already used
  $class = join('',$base,++$i) while ( 
       is_class_loaded($class)
    || Module::Locate::locate($class)
  );
  
  $class
};


# Don't use any of the defaults from the superclass:
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

has '_psgi_app', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  $self->ensure_bootstrapped(1);
  
  my $c = $self->appname;
  $c->apply_default_middlewares($c->psgi_app)
  
}, init_arg => undef;

sub psgi_app { (shift)->to_app(@_) }

# Plack::Component methods:

sub prepare_app { (shift)->ensure_bootstrapped }

sub call {
  my ($self, $env) = @_;
  $self->_psgi_app->($env)
}


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

This module is an extension to both L<Plack::Component> and L<CatalystX::AppBuilder> and 
facilitates programatically creating/instantiating a RapidApp application without having to 
setup/bootstrap files on disk. As a L<Plack::Component>, it can also be used anywhere Plack
is supported, and subclassed in the same manner as L<Plack::Component>.

...

=head1 CONFIGURATION

=head2 appname

Class name of the RapidApp/Catalyst app to be built.

=head2 base_appname

Alternative to C<appname>, but will append a number if the specified class already exists (loaded
or unloaded, but found in @INC). For example, if set to C<MyApp>, if MyApp already exists, the appname 
is set to <MyApp1>, if that exists it is set to C<MyApp2> and so on.

=head2 plugins

List of Catalyst plugins to load. The plugin 'RapidApp' is always loaded, and '-Debug' is loaded
when C<debug> is set.

=head2 debug

Boolean flag to enable debug output in the application. When set, adds C<-Debug> to the plugins 
list.

=head2 version

The C<$VERSION> string to use


=head1 METHODS

=head2 psgi_app

Same as C<to_app>

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


