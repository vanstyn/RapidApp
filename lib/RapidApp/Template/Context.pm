package RapidApp::Template::Context;
use strict;
use warnings;
use autodie;

use RapidApp::Include qw(sugar perlutil);
use Text::Markdown 1.000031 'markdown';
use Switch qw(switch);

use Moo;
extends 'Template::Context';

=pod

=head1 DESCRIPTION

Base Template Context class with extended API for post-process parsing (i.e. markup rendering)
and template div wrapping for attaching metadata. Extends L<Template::Context>. 
Designed specifically to work with RapidApp::Template::Controller.

=cut

# The RapidApp::Template::Controller instance
has 'Controller', is => 'ro', required => 1;

# The RapidApp::Template::Access instance:
# We need to be able to check certain template permissions for special markup
# Actual permission checks happen in the RapidApp::Template::Controller
has 'Access', is => 'ro', required => 1;

sub get_Provider {
  my $self = shift;
  return $self->{LOAD_TEMPLATES}->[0];
}

sub div_wrap {
  my ($self,$template) = @_;
  return 0 unless $self->Controller->{_div_wrap}; #<-- localized in RapidApp::Template::Controller
  return $self->Access->template_writable($template);
}

around 'process' => sub {
  my ($orig, $self, @args) = @_;

  # This is probably a Template::Document object:
  my $template = blessed $args[0] ? $args[0]->name : $args[0];
  
  my $output = $self->$orig(@args);
  
  return $self->post_process_output($template,\$output);
};


# New/extended API:
sub post_process_output {
  my ($self, $template, $output_ref) = @_;
  
  my $format = $self->Access->get_template_format($template)
    or die "Access object didn't return a format string";
  
  # TODO: defer to actual format class/object, TBD
  switch ($format) {
    case 'markdown' {
      $$output_ref = markdown($$output_ref);
    }
  }
  
  return $self->div_wrap($template)
    ? $self->_div_wrap_content($template,$format,$$output_ref)
    : $$output_ref;
}


sub _div_wrap_content {
  my ($self, $template, $format, $content) = @_;
  
  my $exists = $self->get_Provider->template_exists($template);
  my $meta = { 
    name => $template,
    format => $format,
    deletable => $exists ? $self->Access->template_deletable($template) : 0
  };
  
  join("\n",
    '<div class="ra-template">',
      
      '<div class="meta" style="display:none;">',
        #'<div class="template-name">' . $template . '</div>',
        #'<div class="template-format">' . $format . '</div>',
        encode_json_utf8($meta),
      '</div>',
      
      (
        $exists ?
        '<div title="Edit \'' . $template . '\'" class="edit icon-edit-pictogram"></div>' :
        ''
      ),
      
      '<div class="content">', $content, '</div>',
      
    '</div>'
  );
}

1;