package Catalyst::Plugin::RapidApp::TabGui;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp';

use RapidApp::Include qw(sugar perlutil);
require Module::Runtime;
require Catalyst::Utils;

sub _navcore_enabled { 
  my $c = shift;
  return (
    $c->does('Catalyst::Plugin::RapidApp::NavCore') ||
    $c->registered_plugins('RapidApp::NavCore') #<-- this one doesn't seem to apply
  ) ? 1 : 0;
}

sub _authcore_enabled { 
  my $c = shift;
  return (
    $c->does('Catalyst::Plugin::RapidApp::AuthCore') ||
    $c->registered_plugins('RapidApp::NavCore') #<-- this one doesn't seem to apply
  ) ? 1 : 0;
}

before 'setup_components' => sub {
  my $c = shift;
  
  my $config = $c->config->{'Plugin::RapidApp::TabGui'} or die
    "No 'Plugin::RapidApp::TabGui' config specified!";
  
  $config->{title} ||= $c->config->{name};  
  $config->{nav_title} ||= $config->{title};
  
  # --- We're aware of the AuthCore plugin, and if it is running we automatically 
  # set a banner with a logout link if no banner is specified:
  if($c->_authcore_enabled) {
    $config->{banner_template} ||= 'templates/rapidapp/simple_auth_banner.tt';
  }
  # ---
  
  my @navtrees = ();
  
  if($config->{template_navtree_regex}) {
   push @navtrees, ({
      module => 'tpl_navtree',
      class => 'RapidApp::AppTemplateTree',
      params => {
        template_regex => $config->{template_navtree_regex},
        default_expanded => $config->{template_navtree_expanded} || 0
      }
    });
  }
  
  # New: add custom navtrees by config:
  push @navtrees, @{$config->{navtrees}} if (exists $config->{navtrees});
  
  # --- We're also aware of the NavCore plugin. If it is running we stick its items
  # at the **top** of the navigation tree:
  unshift @navtrees, (
    {
      module => 'navtree',
      class => 'Catalyst::Plugin::RapidApp::NavCore::NavTree',
      params => {
        title => 'Foo'
      }
    },
    { xtype => 'spacer', height => '5px' } 
  ) if ($c->_navcore_enabled);
  # ---
  
  # Turn off the navtree if it has no items:
  $config->{navtree_disabled} = 1 unless (@navtrees > 0);
  
  my $main_module_params = {
    title => $config->{nav_title},
    right_footer => $config->{title},
    iconCls => $config->{nav_title_iconcls} || 'ra-icon-catalyst-transparent',
    init_width => $config->{navtree_init_width} || 230,
    navtrees => \@navtrees
  };
  
  if($config->{dashboard_template}) {
    $main_module_params->{dashboard_class} = 'RapidApp::AppHtml';
    $main_module_params->{dashboard_params} = {
      get_html => sub {
        my $self = shift;
        my $vars = { c => $self->c };
        return $self->c->template_render($config->{dashboard_template},$vars);
      }
    };
  }
  
  # remap banner_template -> header_template
  $main_module_params->{header_template} = $config->{banner_template}
    if($config->{banner_template});
  
  my @copy_params = qw(
    dashboard_url
    navtree_footer_template
    navtree_load_collapsed
    navtree_disabled
  );
  $config->{$_} and $main_module_params->{$_} = $config->{$_} for (@copy_params);
  
  # -- New: enable passthrough to exclude navtrees that define 
  # a 'require_role' property (See new API in RapidApp::AppExplorer)
  $main_module_params->{role_checker} = 
    $c->config->{'Plugin::RapidApp::AuthCore'}{role_checker}
    if ($c->_authcore_enabled);
  # --
  
  my $cnf = {
    rootModuleClass => 'RapidApp::RootModule',
    rootModuleConfig => {
      app_title => $config->{title},
      main_module_class => 'RapidApp::AppExplorer',
      main_module_params => $main_module_params
    }
  };
    
  # Apply base/default configs to 'Model::RapidApp':
  $c->config( 'Model::RapidApp' => 
    Catalyst::Utils::merge_hashes($cnf, $c->config->{'Model::RapidApp'} || {} )
  );
};

1;


__END__

=head1 NAME

Catalyst::Plugin::RapidApp::TabGui - Instant tabbed Ajax admin navigation interface

=head1 SYNOPSIS

 package MyApp;
 
 use Catalyst   qw/ RapidApp::TabGui /;

=head1 DESCRIPTION

The TabGui plugin is the primary high-level turn-key interface paradigm provided by the
RapidApp distribution for top-most level GUIs (i.e. to be loaded in a full-browser, not within
another interface). It provides a standard admin-style interface, based on ExtJS, with an (optional)
navigation tree on the left-hand side and a tabbed content panel on the right, with an optional
banner section at the top.

The content area hooks into a RESTful URL navigation scheme to load various kinds of content
at public paths in the application, including both RapidApp-specific Module views as well as
ordinary HTML content returned by ordinary controllers.

The interface is pure Ajax with no browser page loads whatsoever, with simulated client-side
URLs triggered via the I<hash> section/mechanism of the URL. These are fully-valid, RESTful
URLs are called "hashnav paths" which start with C<#!/> such as:

 /#!/some/url/path

The above URL loads the content of C</some/url/path> with a new tab (or existing tab if already 
open) and works just as well if the TabGui is already loaded as accessing the url from a 
fresh browser window.

The TabGui is loaded at the root module, which defaults to root of the Catalyst app C</> for
a dedicated application, but can also be changed to provide an admin section for an existing 
app by setting the C<module_root_namespace> RapidApp config:

 # in the main catalyst app class:
 __PACKAGE__->config(
  # ...
  'RapidApp' => {
    module_root_namespace => 'adm',
    # ...
  }
 );

In this case, the interface would be accessible via C</adm>, and in turn, the previous hashnav 
URL example would be:

 /adm/#!/some/url/path

The TabGui is automatically loaded and configured by other high-level plugins, most notably,
L<RapidDbic|Catalyst::Plugin::RapidApp::RapidDbic>.

Thus, the following are exactly equivalent:

 use Catalyst qw/
   RapidApp::TabGui
   RapidApp::RapidDbic
 /

 use Catalyst qw/
   RapidApp::RapidDbic
 /

Additionally, there are multiple extra plugins with provide high-level functionality which 
assume, build upon and/or otherwise interact with the TabGui as the primary navigation interface, 
such as L<NavCore|Catalyst::Plugin::RapidApp::NavCore> and 
L<CoreSchemaAdmin|Catalyst::Plugin::RapidApp::CoreSchemaAdmin>.

The TabGui plugin itself is just a configuration layer. Internally, it assembles and automatically 
configures a number of RapidApp modules which provide the actual functionality, including 
L<RapidApp::AppExplorer>, L<RapidApp::AppTree> and others.

=head1 SEE ALSO

=over

=item *

L<RapidApp::Manual::Plugins>

=item *

L<Catalyst::Plugin::RapidApp>

=item *

L<Catalyst::Plugin::RapidApp::RapidDbic>

=item *

L<Catalyst::Plugin::RapidApp::NavCore>

=item * 

L<Catalyst>

=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


1;
