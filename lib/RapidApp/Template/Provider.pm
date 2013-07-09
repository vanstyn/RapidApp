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

# The RapidApp::Template::Access instance:
# We need to be able to check certain template permissions for special markup
# Actual permission checks happen in the RapidApp::Template::Controller
has 'Access', is => 'ro', required => 1;

# Whether or not to wrap writable templates in a special <div> tag for target/selection
# in JavaScript client (for creating edit selector/tool GUI)
has 'div_wrap', is => 'ro', default => sub{0};

# This only applies to filesystem-based templates and when creatable templates are enabled:
has 'new_template_path', is => 'ro', lazy => 1, default => sub{
  my $self = shift;
  # default to the first include path
  my $paths = $self->paths or die "paths() didn't return a true value";
  return $paths->[0];
};

has 'default_new_template_content', is => 'ro', default => sub{'BLANK TEMPLATE'};

has 'wrapper_template_name', is => 'ro', default => sub{ '___internal_template_wrapper___' };

around 'fetch' => sub {
  my ($orig, $self, $name) = @_;
  
  # Save the template fetch name:
  local $self->{template_fetch_name} = $name;
  return $self->$orig($name);
};

around '_template_modified' => sub {
  my ($orig, $self, @args) = @_;
  my $template = $self->{template_fetch_name} || join('/',@args);
  
  return 1 if ($template eq $self->wrapper_template_name);
  
  my $modified = $self->$orig(@args);
  
  # Need to return a virtual value to enable the virtual content for
  # creating non-extistent templates
  $modified = 1 if (
    ! $modified &&
    ! $self->{template_exists_call} && #<-- localized in template_exists() below
    ! $self->template_exists($template) &&
    $self->Access->template_creatable($template)
  );
  
  return $modified;
};

# Wraps writable templates with a div (if enabled)
around '_template_content' => sub {
  my ($orig, $self, @args) = @_;
  my $template = $self->{template_fetch_name} || join('/',@args);

  my ($data, $error, $mod_date); 
  
  if($template eq $self->wrapper_template_name) {
    ($data, $error, $mod_date) = (
      $self->_get_wrapper_template, undef, 1
    );
  }
  else {
  
  
  
    if($self->template_exists($template)) {
      my $editable = $self->div_wrap && $self->Access->template_writable($template);
      ($data, $error, $mod_date) = $self->$orig(@args);
      # Wrap with div selectors for processing in JS:
      $data = $self->_div_wrap_content($template, $data) if $editable;
    }
    else {
      # Return virtual non-existent content, optionally with markup 
      # to enable on-the-fly creating the template:
      ($data, $error, $mod_date) = (
        $self->_not_exist_content(
          $template, 
          ($self->div_wrap && $self->Access->template_creatable($template))
        ), undef, 1
      );  
    }
    
    $data = $self->_new_wrap_content($template,$data);
  
  }
  
  return wantarray
    ? ( $data, $error, $mod_date )
    : $data;
};


sub _new_wrap_content {
 my ($self, $template, $content) = @_;
  join(" ",
    '[% WRAPPER',$self->wrapper_template_name,
      'template ="',$template,'" %]',
      $content,
    '[% END %]'
  );
}



sub _div_wrap_content {
  my ($self, $template, $content) = @_;
  join("\n",
    '<div class="ra-template">',
      
      '<div class="meta" style="display:none;">',
        '<div class="template-name">', $template, '</div>',
      '</div>',
      
      '<div title="Edit \'' . $template . '\'" class="edit icon-edit-pictogram"></div>',
      
      '<div class="content">', $content, '</div>',
      
    '</div>'
  );
}

sub _not_exist_content {
  my ($self, $template,$creatable) = @_;
  
  my $inner = $creatable
    ? 'Template <span class="tpl-name">' . $template . '</span> doesn\'t exist yet' .
        '<div title="Create \'' . $template . '\'" class="create with-icon icon-selection-add">Create Now</div>'
    : 'Template <span class="tpl-name">' . $template . '</span> doesn\'t exist';
  
  my $outer = $creatable
    ? '<div class="not-exist creatable">' . $inner . '</div>'
    : '<div class="not-exist">' . $inner . '</div>';
  
  return join("\n",
    '<div class="ra-template">',
      
      '<div class="meta" style="display:none;">',
        '<div class="template-name">', $template, '</div>',
      '</div>',
      
      $outer,

    '</div>'
  );
}

sub _template_error_content {
  my ($self, $template, $error, $editable) = @_;
  join("\n",
    '<div class="ra-template">',
      
      '<div class="meta" style="display:none;">',
        '<div class="template-name">', $template, '</div>',
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

###
### Over and above the methods in the Template::Provider API:
###



sub _get_wrapper_template {
<<'--END--',
[% IF tpl_editable %]
##### start [% template %] #####
[% content %]
##### end [% template %] #####
[% ELSE %][% content %][% END %]
--END--
}


# Simple support for writing to filesystem-based templates to match the
# default Template::Provider for reading filesystem-based templates. Note
# that the permission check happens in the RapidApp::Template::Controller,
# before this method is called.
sub update_template {
  my ($self, $template, $content) = @_;
  
  my $path = $self->get_template_path($template);
  my $File = file($path);
  
  die "Bad template path '$File'" unless (-f $File);
  
  return $File->spew($content);
}

sub template_exists {
  my ($self, $template) = @_;
  local $self->{template_exists_call} = 1;
  return $self->get_template_path($template) ? 1 : 0;
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

sub create_template {
  my ($self, $template, $content) = @_;
 
  my $File = file($self->new_template_path,$template);
  die "create_templete(): ERROR - $File already exists!" if (-f $File);
  
  my $Dir = $File->parent;
  unless (-d $Dir) {
    $Dir->mkpath or die "create_templete(): mkpath failed for '$Dir'";
  }
  
  $content = $self->default_new_template_content
    unless (defined $content);

  $File->spew($content);
  
  return -f $File ? 1 : 0;
}

1;