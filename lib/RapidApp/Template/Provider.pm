package RapidApp::Template::Provider;
use strict;
use warnings;
use autodie;

use RapidApp::Include qw(sugar perlutil);
use Path::Class qw(file);

use Moo;
extends 'Template::Provider';

=pod

=head1 DESCRIPTION

Base Template Provider class with extended API for updating templates. Extends L<Template::Provider>
and, like that class, works with filesystem based templates, including updating of filesystem
templates. Designed specifically to work with RapidApp::Template::Controller.

=cut

# The RapidApp::Template::Controller instance
has 'Controller', is => 'ro', required => 1;

# Whether or not to wrap writable templates in a special <div> tag for target/selection
# in JavaScript client (for creating edit selector/tool GUI)
has 'div_wrap', is => 'ro', default => sub{0};

# $c - localized by RapidApp::Template::Controller specifically
sub catalyst_context { (shift)->Controller->{_current_context} }

# Global setting (delegated to the Controller)
sub writable { (shift)->Controller->writable }


around 'fetch' => sub {
  my ($orig, $self, $name) = @_;
  
  # Save the template fetch name:
  local $self->{template_fetch_name} = $name;
  return $self->$orig($name);
};

# For reference: this method needs to be overridden for custom Provider
# returns an mtime/serial
around '_template_modified' => sub {
  my ($orig, $self, @args) = @_;
  my $ret = $self->$orig(@args);
  return $ret;
};

# Wraps writable templates with a div (if enabled)
around '_template_content' => sub {
  my ($orig, $self, @args) = @_;
  my $template = $self->{template_fetch_name} || join('/',@args);

  my ( $data, $error, $mod_date ) = $self->$orig(@args);
  
  # Wrap with div selectors for processing in JS:
  $data = join("\n",
    '<div class="ra-template">',
      
      '<div class="meta" style="display:none;">',
        '<div class="template-name">', $template, '</div>',
      '</div>',
      
      '<div title="Edit \'' . $template . '\'" class="edit icon-edit-pictogram"></div>',
      
      '<div class="content">', $data, '</div>',
      
    '</div>'
  ) if ($self->div_wrap && $self->_template_writable($template));

  return wantarray
    ? ( $data, $error, $mod_date )
    : $data;
};


###
### Over and above the methods in the Template::Provider API:
###


# normalized function interface (pass through to coderef)
# DO NOT OVERRIDE
sub _template_writable { 
  my $self = shift;
  return $self->writable ? #<-- check global writable setting
    $self->template_writable_coderef->($self,@_) : 0;
}

# CodeRef to determine if a given template is allowed to be updated:
has 'template_writable_coderef', is => 'ro', default => sub {
  return sub {
    my $self = shift;
    # default pass-through to class method:
    return $self->template_writable(@_);
  };
};

# optional class/method function to override 
# (instead of supplying template_writable_coderef)
sub template_writable {
  my ($self,@args) = @_;
  my $template = join('/',@args);
  
  # Default allows all
  return 1;
}

# Pre-check writable permission
# DO NOT OVERRIDE:
sub _update_template {
  my ($self, $template, $content) = @_;
  
  die "_update_template(): '$template' is not writable"
    unless $self->_template_writable($template);
 
  return $self->update_template($template,$content);
}

# This is just proof-of-concept support for writing to filesystem-based templates,
# (the built-in mode of Template::Provider). This could be *very* dangerous, 
#  REMOVE BEFORE PRODUCTION RELEASE
sub update_template {
  my ($self, $template, $content) = @_;
  
  my $path = $self->get_template_path($template);
  my $File = file($path);
  
  die "Bad template path '$File'" unless (-f $File);
  
  return $File->spew($content);
}


# Copied from Template::Provider::load
sub get_template_path {
    my ($self, $name) = @_;
    my ($data, $error);
    my $path = $name;
 
    if (File::Spec->file_name_is_absolute($name)) {
        # absolute paths (starting '/') allowed if ABSOLUTE set
        $error = "$name: absolute paths are not allowed (set ABSOLUTE option)"
            unless $self->{ ABSOLUTE };
    }
    elsif ($name =~ m[$Template::Provider::RELATIVE_PATH]o) {
        # anything starting "./" is relative to cwd, allowed if RELATIVE set
        $error = "$name: relative paths are not allowed (set RELATIVE option)"
            unless $self->{ RELATIVE };
    }
    else {
      INCPATH: {
          # otherwise, it's a file name relative to INCLUDE_PATH
          my $paths = $self->paths()
              || return ($self->error(), Template::Constants::STATUS_ERROR);
 
          foreach my $dir (@$paths) {
              $path = File::Spec->catfile($dir, $name);
              last INCPATH
                  if $self->_template_modified($path);
          }
          undef $path;      # not found
      }
    }

  #######

  return $path;
}

1;