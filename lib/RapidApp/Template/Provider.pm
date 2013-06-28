package RapidApp::Template::Provider;
use strict;
use warnings;
use autodie;

use RapidApp::Include qw(sugar perlutil);
use Path::Class qw(file);

use Moo;
extends 'Template::Provider';

has 'div_wrap', is => 'ro', default => sub{0};

around 'fetch' => sub {
  my ($orig, $self, $name) = @_;
  
  # Save the fetch name:
  local $self->{template_fetch_name} = $name;
  return $self->$orig($name);
};

around '_template_modified' => sub {
  my ($orig, $self, @args) = @_;

  my $ret = $self->$orig(@args);
  
  return $ret;
};


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
      
      '<div class="highlight">',
        '<div title="Edit \'' . $template . '\'" class="edit icon-edit-pictogram"></div>',
      '</div>',
      
      '<div class="content">', $data, '</div>',
      
    '</div>'
  ) if ($self->div_wrap);

  return wantarray
    ? ( $data, $error, $mod_date )
    : $data;
};

# Over and above the Template::Provider API:

# This is just proof-of-concept support for writing to filesystem-based templates,
# (the built-in mode of Template::Provider). This could be *very* dangerous, 
#  REMOVE BEFORE PRODUCTION RELEASE
sub _update_template {
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