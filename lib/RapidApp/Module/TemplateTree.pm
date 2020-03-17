package RapidApp::Module::TemplateTree;

use strict;
use warnings;

use Moose;
extends 'RapidApp::Module::NavTree';

=pod

=head1 DESCRIPTION

Special nav tree designed to display templates from the Template::Controller
system (RapidApp::Template::*)

=cut

use RapidApp::Util qw(:all);

has '+fetch_nodes_deep', default => 0;
has 'template_regex', is => 'ro', isa => 'Maybe[Str]', default => sub {undef};

sub TC { (shift)->c->template_controller }

sub folder_template_tree_items {
  my $self = shift;
  my $items = $self->template_tree_items;
  return $self->folder_convert($items);
}

sub template_tree_items {
  my $self = shift;

  my $TC = $self->TC;
  my $templates = $TC->get_Provider->list_templates($self->template_regex);

  my $items = [];
  foreach my $template (@$templates) {
    my $cnf = {
      id => 'tpl-' . $template,
      leaf => \1,
      name => $template,
      text => $template,
      iconCls => 'ra-icon-page-white-world',
      loadContentCnf => { autoLoad => { url => join('/',$TC->tpl_path,$template) }},
      loaded => \1
    };

    $self->apply_tpl_node($cnf);
    push @$items, $cnf;
  }

  return $items;
}


sub apply_tpl_node {
  my ($self, $node) = @_;
  my $template = $node->{name} or return;

  %$node = ( %$node,
    iconCls => 'ra-icon-page-white',
    text => join('',
      '<span style="color:purple;">',
      $node->{text},
      '</span>'
    )
  ) if $self->TC->Access->template_external_tpl($template);
}


sub fetch_nodes {
  my $self = shift;
  my ($node) = @_;

  my $items;

  # Return the root node without children to spare the
  # template query until it is actually expanded (unless default_expanded is set):
  if ($node eq 'root') {
    $items = [{
      id      => 'tpl-list',
      text    => 'Templates',
      expanded  => $self->default_expanded ? \1 : \0,
    }];
    $items->[0]->{children} = $self->folder_template_tree_items
      if ($self->default_expanded);
  }
  else {
    # The only other possible request is for the children of
    # 'root/tpl-list' above:
    $items = $self->folder_template_tree_items;
  }

  return $items;
}

# Splits and converts a flat list into an ExtJS tree/folder structure
sub folder_convert {
  my ($self, $items) = @_;

  my $root = [];
  my %seen = ( '' => $root );

  foreach my $item (@$items) {
    my @parts = split(/\//,$item->{name});
    my $leaf = pop @parts;

    my @stack = ();
    foreach my $part (@parts) {
      my $parent = join('/',@stack) || '';
      push @stack, $part;
      my $folder = join('/',@stack);

      unless($seen{$folder}) {
        my $cnf = {
          id => 'tpl-' . $folder . '/',
          name => $folder . '/',
          text => $part,
          expanded  => $self->default_expanded ? \1 : \0,
          children => []
        };
        $self->apply_tpl_node($cnf);
        delete $cnf->{iconCls} if (exists $cnf->{iconCls});
        $seen{$folder} = $cnf->{children};
        push @{$seen{$parent}}, $cnf;
      }
    }

    my $folder = join('/',@stack);
    my $new = {
      %$item,
      text => $leaf
    };
    $self->apply_tpl_node($new);
    push @{$seen{$folder}}, $new;
  }
  return $root;
}



1;
