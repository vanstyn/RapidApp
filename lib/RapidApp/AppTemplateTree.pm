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

has '+fetch_nodes_deep', default => 0;
has 'template_regex', is => 'ro', isa => 'Maybe[Str]', default => sub {undef};

sub template_tree_items {
	my $self = shift;
  
  my $TC = $self->c->template_controller;
  my $templates = $TC->get_Provider->list_templates($self->template_regex);
  
  my $items = [];
  foreach my $template (@$templates) {
    my $cnf = {
      id => 'tpl-' . $template,
      leaf => \1,
      text => $template,
      iconCls => 'ra-icon-page-white-world',
      href => '#!/tple/' . $template,
      loaded => \1
    };
    
    # Show 'external' templates differently:
    if($TC->Access->template_external_tpl($template)) {
      $cnf->{iconCls} = 'ra-icon-page-white';
      $cnf->{text} = join('',
        '<span style="color:purple;">',
        $cnf->{text},
        '</span>'
      )
    }
    
    push @$items, $cnf;
  }
  
  return $items;
}



sub fetch_nodes {
	my $self = shift;
	my ($node) = @_;
  
  # Return the root node without children to spare the
  # template query until it is actually expanded:
  return [{
		id			=> 'tpl-list',
		text		=> 'Templates',
		expand		=> 0,
	}] if ($node eq 'root');
  
	# The only other possible request is for the children of 
  # 'root/tpl-list' above:
	return $self->template_tree_items;
}



1;
