package RapidApp::Module::HtmlContent;

use strict;
use warnings;

use Moose;
extends 'RapidApp::Module::ExtComponent';

use RapidApp::Util qw(:all);

# This class exists just to properly setup a container with correct scrollbars, 
# in all browsers (including IE), to contain simple HTML. Derived class should
# provide an "html" method that will return the html content, called on each
# request.

# but yet it still doesn't work right with dynamic content in IE

# here is a trick for the html:
#<div style="position:absolute; left: 0px;right:25px;">


### TODO: making <script> tags work within the HTML:
###
### By default ExtJS will ignore <script> in the html. But, I discovered
### the way to make it work:
###
###  1. set the 'html' to an empty string
###  2. put the real html in a special property, like 'active_html'
###  3. Write an ExtJS plugin to look for this property and then on 
###     'afterrender' (maybe 'render') call:
###
###         this.body.update(this.active_html,true);
###
###     where the scope is the panel (this). The second 'true' arg tells it
###     to include script.


sub BUILD {
  my $self = shift;
  
  $self->apply_extconfig(
    xtype => 'panel',
    layout => 'anchor',
    autoScroll => \1,
  );
}

has 'get_html', is => 'ro', isa => 'CodeRef', lazy => 1, default => sub {
  my $self = shift;
  return sub { $self->html };
};

sub html { die "Virtual Method!" } 

around 'content' => sub {
  my $orig = shift;
  my $self = shift;
  
  my $html =  $self->get_html->($self);
  
  my $content = $self->$orig(@_);
  
  $content->{html} = $html;
  
  return $content;
};

1;
