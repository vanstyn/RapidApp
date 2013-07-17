package RapidApp::Template::Context;
use strict;
use warnings;
use autodie;

use RapidApp::Include qw(sugar perlutil);
use Text::Markdown 1.000031 'markdown';

use Moo;
extends 'Template::Context';

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
  
  # just for testing, parse markdown for *.md templates:
  if ($template =~ /\.md$/) {
    return markdown($$output_ref);
  }

  return $$output_ref;
}

1;