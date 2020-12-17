package RapidApp::Template::Context;
use strict;
use warnings;
use autodie;

use RapidApp::Util qw(:all);
use Try::Tiny;

use Moo;
extends 'Template::Context';

use namespace::clean;

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

sub process_template_stack { @{(shift)->{_process_template_stack} || []} }
sub process_nest_level     { scalar( (shift)->process_template_stack )    }

around 'process' => sub {
  my ($orig, $self, @args) = @_;
  
  local $self->Access->{_process_Context} = $self;
  
  # This is probably a Template::Document object:
  my $template = blessed $args[0] ? $args[0]->name : $args[0];
  $template = $self->Controller->_resolve_template_name($template);
  
  # Localize to track a stack of templates, when templates include other templates:
  local $self->{_process_template_stack} = [ $template, $self->process_template_stack ];
  
  my $output;
  try {
    if($self->Access->template_static_tpl($template) && $self->get_Provider->template_exists($template)) {
      # If this is a 'static' template, do not process it through TT, 
      # instead return the raw template content directly
      ($output) = $self->get_Provider->load($template);
    }
    else {
      $output = $self->$orig(@args);
    }
    
    $output = $self->post_process_output($template,\$output);
  }
  catch {
    my $err = shift;
    
    # Rethrow if this flag is set. This is needed specifically for
    # the special _get_template_error() case in RapidApp::Template::Controller
    die $err if ($self->Controller->{_no_exception_error_content});
    
    $output = $self->_template_error_content(
      $template, $err,
      $self->Access->template_writable($template)
    );
  };
  
  return $output;
};


sub get_template_post_processor {
  my ($self, $template) = @_;
  
  if(my $class = $self->Access->template_post_processor_class($template)) {
    unless ($self->{_loaded_post_processor_classes}{$class}) {
      Module::Runtime::require_module($class);
      $class->can('process') or die "FATAL: Postprocessor '$class' has no 'process' method!";
      $self->{_loaded_post_processor_classes}{$class}++;
    }
    return $class
  }
  return undef
}

sub next_template { ((shift)->process_template_stack)[1] }


# Returns the post-processor class of the *next* template (i.e. the second element)
# in the process_template_stack. This is intended to be called from a post-processor
# so it can apply logic according to the template it is nested within. For example,
# if a markdown template includes another markdown template, we only want to convert
# the markdown when post-processing the
sub next_template_post_processor {
  my $self = shift;
  
  my $next_template = $self->next_template or return undef;
  $self->get_template_post_processor($next_template)
}


# New/extended API:
sub post_process_output {
  my ($self, $template, $output_ref) = @_;

  my $meta = $self->{_cached_template_metadata}{$template} //= {
    format        => $self->Access->get_template_format($template),
    postprocessor => $self->get_template_post_processor($template)
  };
  
  die "Access object didn't return a format string" unless ($meta->{format});
  
  $$output_ref = $meta->{postprocessor}->process($output_ref,$self) if ($meta->{postprocessor});
  
  return $self->div_wrap($template)
    ? $self->_div_wrap_content($template,$meta->{format},$$output_ref)
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
        encode_json_ascii($meta),
      '</div>',
      
      (
        $exists ?
        '<div title="Edit \'' . $template . '\'" class="edit ra-icon-edit-pictogram"></div>' :
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
        encode_json_ascii({ 
          name => $template,
          format => $self->Access->get_template_format($template),
          deletable => $self->Access->template_deletable($template)
        }),
      '</div>',
      
      ( $editable 
        ? '<div title="Edit \'' . $template . '\'" class="edit ra-icon-edit-pictogram"></div>'
        : ''
      ),
      
      '<div class="tpl-error">', 
        'Template error &nbsp;&ndash; <span class="tpl-name">' . $template . '</span>',
        '<div class="error-msg">',$error,'</div>',
      '</div>',
      
    '</div>'
  );
}


##################################################
# -- NEEDED FOR SECURITY FOR NON-PRIV USERS --
#  DISABLE ALL PLUGINS AND FILTERS EXCEPT THOSE 
#  SPECIFICALLY CONFIGURED TO BE ALLOWED
has '_allowed_plugins_hash', default => sub {
  my $self = shift;
  return { map {lc($_)=>1} @{$self->Controller->allowed_plugins} };
}, is => 'ro', lazy => 1;

has '_allowed_filters_hash', default => sub {
  my $self = shift;
  return { map {lc($_)=>1} @{$self->Controller->allowed_filters} };
}, is => 'ro', lazy => 1;

around 'plugin' => sub {
  my ($orig, $self, $name, @args) = @_;
  
  return $self->throw(
    Template::Constants::ERROR_PLUGIN, 
    "USE '$name' - permission denied"
  ) unless ($self->_allowed_plugins_hash->{lc($name)});
    
  return $self->$orig($name,@args);
};

around 'filter' => sub {
  my ($orig, $self, $name, @args) = @_;
  
  return $self->throw(
    Template::Constants::ERROR_FILTER, 
    "Load Filter '$name' - permission denied"
  ) unless ($self->_allowed_filters_hash->{lc($name)});
    
  return $self->$orig($name,@args);
};
##################################################



1;