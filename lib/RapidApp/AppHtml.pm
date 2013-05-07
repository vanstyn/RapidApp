package RapidApp::AppHtml;
use strict;
use Moose;
extends 'RapidApp::AppCmp';

use RapidApp::Include qw(sugar perlutil);

# This class exists just to properly setup a container with correct scrollbars, 
# in all browsers (including IE), to contain simple HTML. Derived class should
# provide an "html" method that will return the html content, called on each
# request.

# but yet it still doesn't work right with dynamic content in IE

# here is a trick for the html:
#<div style="position:absolute; left: 0px;right:25px;">


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