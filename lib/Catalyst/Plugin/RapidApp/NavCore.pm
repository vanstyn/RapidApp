package Catalyst::Plugin::RapidApp::NavCore;
use Moose::Role;
use namespace::autoclean;

with 'Catalyst::Plugin::RapidApp::CoreSchema';

use RapidApp::Util qw(:all);
use CatalystX::InjectComponent;

after 'setup_components' => sub { (shift)->_navcore_inject_controller(@_) };
sub _navcore_inject_controller {
  my $c = shift;
  
  CatalystX::InjectComponent->inject(
    into => $c,
    component => 'Catalyst::Plugin::RapidApp::NavCore::Controller',
    as => 'Controller::View'
  );
  
  $c->_navcore_init_default_public_nav_items(0);
};


sub _navcore_init_default_public_nav_items {
  my ($c, $force) = @_;
  
  my $cfg  = clone($c->config->{'Plugin::RapidApp::NavCore'} || {});
  my $itms = $cfg->{default_public_nav_items} or return;
  
  # Only auto-init to a clean slate
  return if (!$force && $c->model('RapidApp::CoreSchema::NavtreeNode')->count > 1);

  warn " ** NavCore: Initializing default public navtree/views from 'default_public_nav_items' ...\n";
  $c->_navcore_create_public_structure($itms,0);

}


sub _navcore_create_public_structure {
  my ($c, $itms, $nav_node_id) = @_;
  
  try {
    $c->model('RapidApp::CoreSchema')->txn_do(sub {
      $c->__navcore_create_public_structure($itms, $nav_node_id);
    });
  }
  catch {
    my $err = shift;
    die $err
  };
}


sub __navcore_create_public_structure {
  my ($c, $itms, $nav_node_id) = @_;
  my $type = ref($itms)||'';
  
  return $c->__navcore_create_public_structure(
    $itms->($c), $nav_node_id
  ) if ($type eq 'CODE');
  
  unless ($type eq 'ARRAY') {
    $type eq 'HASH'
      ? $itms = [$itms]
      : die "items must be supplied as an ArrayRef or a CodeRef which returns an ArrayRef"
  }
  
  $nav_node_id //= 0; # root node
  
  my $nRs = $c->model('RapidApp::CoreSchema::NavtreeNode');
  my $sRs = $c->model('RapidApp::CoreSchema::SavedState');
  
  for my $itm (@$itms) {
    my $create = clone($itm);
    if(my $children = $itm->{children}) {
      
      delete $create->{children};
      $create->{pid} = $nav_node_id;
      my $NavNode = $nRs->create($create);
      
      $c->__navcore_create_public_structure($children,$NavNode->get_column('id'));
    }
    else {
      $create->{node_id} = $nav_node_id;
      $create->{title} ||= delete $create->{text} if ($create->{text});
      $sRs->create($create);
    }
  }
  
  1
}



1;

__END__


=head1 NAME

Catalyst::Plugin::RapidApp::NavCore - Saved views and editable navtrees for RapidDbic

=head1 SYNOPSIS

 package MyApp;
 
 use Catalyst   qw/
   RapidApp::RapidDbic
   RapidApp::NavCore
 /;

=head1 DESCRIPTION

This plugin adds saved views to DBIC grid modules (such as those automatically setup by
the RapidDbic plugin). This adds a "Save Search" option to the "Options" toolbar menu in
supported grids. This allows persisting the state of a given grid, such as the custom
column configuration, sort options, filter set, and so on, to be retrieved again later. Saved
Searches are given a custom name which then appear in the automatic navigation tree provided in
L<TabGui|Catalyst::Plugin::RapidApp::TabGui>/L<RapidDbic|Catalyst::Plugin::RapidApp::RapidDbic>.

Additionally, loading this plugin adds an "Organize Tree" menu point to the navigation tree
which provides a drag and drop interface to organize the tree, add folder structures, rename,
delete and copy the previously saved views.

When used in tandem with the L<AuthCore|Catalyst::Plugin::RapidApp::AuthCore> plugin, each
user is given their own, private folder of saved searches which show up under "My Views" in the 
navtree, in addition to the public saved searches which show up the same for all users.

When used in this mode, the Save Search dialog provides a checkbox to save as a "public" view
rather than a private view, for only the current user. This option is only available if the
user has public search rights (which defaults to users with the 'administrator' role). Additionally,
administrators are able to access the views of other users from the Organize Navtree interface,
and can drag and drop searches between users as well as between the public section and users, and
visa versa.

The saved views are made accessible via virtual controller path under C</view/[search_id]> in
the application which translate into the real module path, with applied saved state data, internally.

Like other Core plugins, NavCore uses 
L<Model::RapidApp::CoreSchema|Catalyst::Model::RapidApp::CoreSchema> 
to persist its data. Internally, the CoreSchema database also has a "DefaultView" source 
which can be used to specify a given saved view to be used by default for each source to
load instead of the default grid state, which is determined according to the schema as well
as any additional global TableSpec configurations.

Default Views can be set via the L<CoreSchemaAdmin|Catalyst::Plugin::RapidApp::CoreSchemaAdmin>
plugin. When NavCore is loaded, these are made available under the "Source Default Views" menu
point under the RapidApp::CoreSchema section in the navtree.

=head1 SEE ALSO

=over

=item *

L<RapidApp::Manual::Plugins>

=item *

L<Catalyst::Plugin::RapidApp::RapidDbic>

=item *

L<Catalyst::Plugin::RapidApp::CoreSchema>

=item *

L<Catalyst::Plugin::RapidApp::CoreSchemaAdmin>

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


