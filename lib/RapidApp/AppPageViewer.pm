package RapidApp::AppPageViewer;
use strict;
use Moose;
extends 'RapidApp::AppHtml';

use RapidApp::Include qw(sugar perlutil);

# Module allows viewing pages in a tab by file name

use Switch qw(switch);

has 'content_dir', is => 'ro', isa => 'Str', required => 1;

sub _requested_file {
  my $self = shift;
  my $dir = $self->content_dir;
  $dir = $self->c->config->{home} . '/' . $dir unless ($dir =~ /^\//);
  
  my $file = $self->c->req->params->{file} or die usererr
    "No file specified", title => "No file specified";
  
  my $path = "$dir/$file";
  
  die usererr "$file not found", title => "No such file"
    unless (-f $path);
  
  my @parts = split(/\./,$file);
  
  my $ext = pop @parts;
  return ($path, $file,$ext);
}

sub html {  
  my $self = shift;
  my ($path, $file, $ext) = $self->_requested_file;
  
  $self->apply_extconfig(
    tabTitle => '<span style="color:darkgreen;">' . $file . '</span>',
    tabIconCls => 'icon-document'
  );
  
  switch(lc($ext)) {
    case('tt') {
      my $vars = { c => $self->c };
      return $self->c->template_render($path,$vars);
    }
    else {
      die usererr "Cannot display $file - unknown file extention type '$ext'", 
        title => "Unknown file type"
    }
  }

} 


1;