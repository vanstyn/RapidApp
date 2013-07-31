package RapidApp::AppTemplateTree;
use strict;
use warnings;
use Moose;
extends 'RapidApp::AppNavTree';

=pod

=head1 DESCRIPTION

Special nav tree designed to display templates from the Template::Controller
system (RapidApp::Template::*)

=cut

use RapidApp::Include qw(sugar perlutil);

has '+fetch_nodes_deep', default => 1;
has 'template_regex', is => 'ro', isa => 'Maybe[Str]', default => sub {undef};

sub template_list {
  my $self = shift;
  my $TC = $self->c->template_controller;
  return $TC->get_Provider->list_templates($self->template_regex);
}

sub template_tree_items {
	my $self = shift;
  
  my $templates = $self->template_list;
  
  return [ map {{
    id => 'tpl-' . $_,
    leaf => \1,
    text => $_,
    iconCls => 'ra-icon-page-white-world',
    href => '#!/tple/' . $_,
    loaded => \1
  }} @$templates ];
}


sub TreeConfig {
  my $self = shift;
  
  my $cnf = [{
		id			=> 'tpl-list',
		text		=> 'Templates',
		expand		=> 0,
		children	=> $self->template_tree_items
	}];
  
  return $cnf;
}


1;
