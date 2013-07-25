package RapidApp::Template::Provider;
use strict;
use warnings;
use autodie;

use RapidApp::Include qw(sugar perlutil);
use Path::Class qw(file dir);

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

around 'fetch' => sub {
  my ($orig, $self, $name) = @_;
  
  # Save the template fetch name:
  local $self->{template_fetch_name} = $name;
  return $self->$orig($name);
};

around '_template_modified' => sub {
  my ($orig, $self, @args) = @_;
  my $template = $self->{template_fetch_name} || join('/',@args);
  
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

  return $self->$orig(@args) if ($self->template_exists($template));

  # Return virtual non-existent content, optionally with markup 
  # to enable on-the-fly creating the template:
  my ($data, $error, $mod_date) = (
    $self->_not_exist_content(
      $template, 
      ($self->div_wrap && $self->Access->template_creatable($template))
    ), undef, 1
  );  
  
  return wantarray
    ? ( $data, $error, $mod_date )
    : $data;
};


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
        #'<div class="template-name">', $template, '</div>',
        encode_json_utf8({ 
          name => $template,
          format => $self->Access->get_template_format($template)
        }),
      '</div>',
      
      $outer,
  
    '</div>'
  );
}


###
### Over and above the methods in the Template::Provider API:
###


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

sub delete_template {
  my ($self, $template) = @_;
 
  my $File = file($self->get_template_path($template));
  die "delete_templete(): ERROR - $File doesn't exist or is not a regular file" 
    unless (-f $File);
    
  unlink($File) or die "delete_templete(): unlink failed for '$File'";
  
  return -f $File ? 0 : 1;
}


sub list_templates {
  my ($self, @regexes) = @_;
  
  my @re = map { qr/$_/ } @regexes;
  my @files = ();
  
  my $paths = $self->{INCLUDE_PATH};
  $paths = [$paths] unless (ref $paths);
  
  my %seen = ();
  for my $dir (map { dir($_) } @$paths) {
    $dir->recurse(
      preorder => 1,
      depthfirst => 1,
      callback => sub {
        my $child = shift;
        return if ($child->is_dir);
        my $tpl = $child->relative($dir)->stringify;
        
        # If regex(es) were supplied, check that the template matches
        # all of them
        !($tpl =~ $_) and return for (@re);
        
        ## If regex(es) were supplied, check that the template matches
        ## at least *one* of them
        #if(scalar(@re) > 0) {
        #  my $m = 0;
        #  for my $r (@re) {
        #    $m++ if ($tpl =~ $r);
        #    last if ($m);
        #  }
        #  return unless ($m > 0);
        #}
        
        # Make sure we include the same physical template only once:
        return if ($seen{$child->absolute->stringify}++);
        
        push @files, $tpl;
      }
    );
  }
  
  return \@files;
}


1;