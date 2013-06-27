package RapidApp::Template::Controller;
use strict;
use warnings;

use RapidApp::Include qw(sugar perlutil);

# New unified controller for displaying and editing TT templates on a site-wide
# basis. This is an experiment that breaks with the previous RapidApp 'Module'
# design. It also is breaking away from DataStore2 for editing nested templates

use Moose;
use namespace::autoclean;

use Template;
use RapidApp::Template::Provider;

BEGIN { extends 'Catalyst::Controller' }

# Maintain two separate Template instances - one that wraps divs and one that
# doesn't. Can't use the same one because compiled templates are cached
has 'Template_raw', is => 'ro', isa => 'Template', lazy => 1, default => sub {
  my $self = shift;
  return $self->_new_Template({ div_wrap => 0 });
};

has 'Template_wrap', is => 'ro', isa => 'Template', lazy => 1, default => sub {
  my $self = shift;
  return $self->_new_Template({ div_wrap => 1 });
};

sub _new_Template {
  my ($self,$opt) = @_;
  return Template->new({ 
    LOAD_TEMPLATES => [
      RapidApp::Template::Provider->new({
        INCLUDE_PATH => $self->_app->default_tt_include_path,
        CACHE_SIZE => 64,
        %{ $opt || {} }
      })
    ] 
  });
}

# TODO: see about rendering with Catalyst::View::TT or a custom View
sub view :Local {
  my ($self, $c, @args) = @_;
  
  my $template = join('/',@args);
  my ($output,$content_type);
  my $vars = { c => $c };
  
  my $ra_req = $c->req->headers->{'x-rapidapp-requestcontenttype'};
  if($ra_req && $ra_req eq 'JSON') {
    # This is a call from within ExtJS, wrap divs to id the templates from javascript
    my $html = $self->_render_template('Template_wrap',$template,$vars);
    
    # This is doing the same thing that the overly complex 'Module' controller does:
    $content_type = 'text/javascript; charset=utf-8';
    $output = encode_json_utf8({
      xtype => 'panel',
      autopanel_parse_title => \1,
      plugins => ['template-controller-panel'],
      html => $html
    });
  }
  else {
    # This is a direct browser call, need to include js/css
    my $text = join("\n",
      '<head>[% c.all_html_head_tags %]</head>',
      '[% INCLUDE ' . $template . ' %]',
    );
    $content_type = 'text/html; charset=utf-8';
    $output = $self->_render_template('Template_raw',\$text,$vars);
  }
  
  $c->response->content_type($content_type);
  $c->response->body($output);
  return $c->detach;
}


sub _render_template {
  my ($self, $meth, $template, $vars) = @_;
  
  my $TT = $self->$meth;
  
  my $output;
  $TT->process( $template, $vars, \$output )
    or die $TT->error;

  return $output;
}

1;