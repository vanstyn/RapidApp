package RapidApp::Template::Provider;
use strict;
use warnings;
use autodie;

use RapidApp::Include qw(sugar perlutil);

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

1;