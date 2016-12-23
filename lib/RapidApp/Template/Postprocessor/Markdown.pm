package RapidApp::Template::Postprocessor::Markdown;
use strict;
use warnings;

use RapidApp::Util qw(:all);
use Text::Markdown 1.000031 'markdown';

# This is the default markdown postprocessor

sub process {
  shift if ($_[0] eq __PACKAGE__);
  my ($output_ref, $context) = @_;
  
  markdown($$output_ref)
}


1;