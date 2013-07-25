package RapidApp::Template::Context;
use strict;
use warnings;
use autodie;

use RapidApp::Include qw(sugar perlutil);
use Text::Markdown 1.000031 'markdown';
use Switch qw(switch);
use Try::Tiny;

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

sub catalyst_context { (shift)->Controller->{_current_context} }

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
  
  my $output;
  try {
    $output = $self->$orig(@args);
    $output = $self->post_process_output($template,\$output);
  }
  catch {
    my $err = shift;
    $output = $self->_template_error_content(
      $template, $err,
      $self->Access->template_writable($template)
    );
  };
  
  return $output;
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

sub _template_error_content {
  my ($self, $template, $error, $editable) = @_;
  
  # Editable override: don't allow edit unless the actual request is
  # in a editable context. This is a bit ugly as it violates the
  # separation of concerns, but this needs to be here to support
  # nested template errors
  $editable = 0 unless (
    $self->Controller->is_editable_request($self->catalyst_context)
  );
  
  join("\n",
    '<div class="ra-template">',
      
      '<div class="meta" style="display:none;">',
        #'<div class="template-name">', $template, '</div>',
        encode_json_utf8({ 
          name => $template,
          format => $self->Access->get_template_format($template),
          deletable => $self->Access->template_deletable($template)
        }),
      '</div>',
      
      ( $editable 
        ? '<div title="Edit \'' . $template . '\'" class="edit icon-edit-pictogram"></div>'
        : ''
      ),
      
      '<div class="tpl-error">', 
        'Template error &nbsp;&ndash; <span class="tpl-name">' . $template . '</span>',
        '<div class="error-msg">',$error,'</div>',
      '</div>',
      
    '</div>'
  );
}

1;