package RapidApp::Helper::Traits::TabGui;
use Moose::Role;

use strict;
use warnings;

requires '_ra_catalyst_plugins';
requires '_ra_catalyst_configs';

around _ra_catalyst_plugins => sub {
  my ($orig,$self,@args) = @_;
  
  my @list = $self->$orig(@args);
  
  return grep { 
    $_ ne 'RapidApp' #<-- Base plugin redundant
  } @list, 'RapidApp::TabGui';
};

around _ra_catalyst_configs => sub {
  my ($orig,$self,@args) = @_;
  
  my @list = $self->$orig(@args);
  
  # Make the TabGui config come first:
  return (
<<END,
    # The TabGui plugin mounts the standard ExtJS explorer interface as the 
    # RapidApp root module (which is at the root '/' of the app by default)
    'Plugin::RapidApp::TabGui' => {
      title => "$self->{name} v\$VERSION",
      nav_title => 'Administration',
      # Templates with the *.md extension render as simple Markdown:
      dashboard_url => '/tple/site/dashboard.md',
      # Make all templates in site/ (root/templates/site/) browsable in nav tree:
      template_navtree_regex => '^site\/'
    },
END
, @list );

};

1;
