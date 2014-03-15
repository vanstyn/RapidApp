package RapidApp::AppPageViewer;
use strict;
use Moose;
extends 'RapidApp::AppHtml';

use RapidApp::Include qw(sugar perlutil);

# Module allows viewing pages in a tab by file name
#
# NOTE: This module has been mostly replaced by the Template::Controller
# system, but it still handles cases, like *.pl and *.pm, that haven't
# been handled yet in the TC, so it is sticking around for now for
# reference (DO NOT USE)
#

use HTML::TokeParser::Simple;
use Text::Markdown 'markdown';
use PPI;
use PPI::HTML;
use Path::Class qw(file);

has 'content_dir', is => 'ro', isa => 'Str', required => 1;
has 'parse_title', is => 'ro', isa => 'Bool', default => 1;
has 'parse_icon_class', is => 'ro', isa => 'Bool', default => 1;
has 'parse_title_style', is => 'ro', isa => 'Bool', default => 1;
has 'alias_dirs', is => 'ro', isa => 'HashRef', default => sub {{}};
has '+accept_subargs', default => 1;

# Allow templates to inline other files via [% inline_file('some/other/file.tt') %]
has 'allow_inline_files', is => 'ro', isa => 'Bool', default => 1;

sub _requested_file {
  my ($self, @path) = @_;
  
  # TODO/FIXME: protect against injection (i.e. what happens if ../../ is supplied?)
  
  my $file =
    # Path from arguments (i.e. called from code)
    join('/',@path)
    || join('/',$self->local_args) 
    || $self->c->req->params->{file} 
    or die usererr "No file specified", title => "No file specified";
  
  my $dir = $self->content_dir;
  my $path = "$dir/$file";
  
  # Optionally remap if file matches a configured alias_dir:
  my @p = split(/\//,$file);
  my $alias = $self->alias_dirs->{(shift @p)};
  $path = join('/',$alias,@p) if ($alias && scalar(@p > 0));

  $path = $self->c->config->{home} . '/' . $path unless ($path =~ /^\//);
  
  # quick/dirty symlink support:
  $path = readlink($path) if (-l $path);
  $path = $self->c->config->{home} . '/' . $path unless ($path =~ /^\//);
  
  die usererr "$file not found", title => "No such file"
    unless (-f $path);
  
  my @parts = split(/\./,$file);
  
  my $ext = pop @parts;
  return ($path, $file,$ext);
}

our $INLINE_FILE_DEPTH = 0;
sub html {  
  my ($self, @args) = @_;
  my ($path, $file, $ext) = $self->_requested_file(@args);
  
  my $content;
  my $lcext = lc($ext);
  
  if($lcext eq 'tt') {
    my $vars = { c => $self->c };
    
    # Closure to support nested/recursive calls from templates to be able to
    # inline the content of other files within the same content_dir scope:
    $vars->{inline_file} = sub { 
      die "('$file')->inline_file(): missing arguments" unless (scalar @_ > 0);
      local $INLINE_FILE_DEPTH;
      die "('$file')->inline_file(): too many recursive calls"
        if (++$INLINE_FILE_DEPTH > 5);
      return $self->html(@_);
    } if ($self->allow_inline_files);
    
    $content = $self->c->template_render($path,$vars);
  }
  elsif($lcext eq 'pl') {
    return $self->_get_syntax_highlighted_perl($path);
  }
  elsif($lcext eq 'pm') {
    return $self->_get_syntax_highlighted_perl($path);
  }
  elsif($lcext eq 'md') {
    return $self->_render_markdown($path);
  }
  ##
  ## TODO: may support non-templates in the future
  
  else {
    die usererr "Cannot display $file - unknown file extention type '$ext'", 
      title => "Unknown file type"
  }
  
  # Only set the tab title if this is not a nested call (i.e. inline_file from a template)
  unless ($INLINE_FILE_DEPTH) {
    my $title = $self->parse_title ? $self->_parse_get_title(\$content) : {};
    $title->{text} ||= $file;
    $title->{class} ||= 'ra-icon-document';
    $self->apply_extconfig(
      tabTitle => '<span style="color:darkgreen;">' . $title->{text} . '</span>',
      tabIconCls => $title->{class}
    );
  }
  
  return $content;
}

sub _parse_get_title {
  my $self = shift;
  my $htmlref = shift;
  
  # Parse tabTitle data from the first <title> tag seen in the html content.
  # Supports special attrs not normally in a <title> tag to also set the
  # tab icon and tab text style, e.g.:
  #  <title class="ra-icon-group" style="color:red">Users</title>
  my $parser = HTML::TokeParser::Simple->new($htmlref);
  while (my $tag = $parser->get_tag) {
    if ($tag->is_tag('title')) {
      my $title = { text => $parser->get_token->as_is };
      my $attr = $tag->get_attr;
      $title->{class} = $attr->{class};
       
      $title->{text} = join('','<span style="', $attr->{style}, '">',
        $title->{text},'</span>'
      ) if ($attr->{style});
      
      return $title;
    }
  }

  return undef;
}


sub _render_markdown {
  my $self = shift;
  my $path = shift;
  
  my $markdown = file($path)->slurp;
  my $html = markdown( $markdown );
  
  return join("\n",
    '<div class="ra-doc">',
    $html,
    '</div>'
  );
}

sub _get_syntax_highlighted_perl {
  my $self = shift;
  my $path = shift;
  
  #Module::Runtime::require_module('PPI');
  #Module::Runtime::require_module('PPI::HTML');
  
  # Load your Perl file
  my $Document = PPI::Document->new( $path );
 
  # Create a reusable syntax highlighter
  my $Highlight = PPI::HTML->new( page => 1, line_numbers => 1 );
  
  # Spit out the HTML
  my $content = &_ppi_css .
    '<div class="PPI">' . 
    $Highlight->html( $Document ) .
    '</div>';
  
  return $content;
}

# This is an ugly temp hack:

sub _ppi_css {
  return qq~
<style>

.PPI br {
  display:none;
}

div.PPI {
  background: #eee;
  border: 1px solid #888;
  padding: 4px;
  font-family: monospace;
}
.PPI CODE {
  background: #eee;
  /* border: 1px solid #888;
     padding: 1px; */
}


.PPI span.word {
    color: darkslategray;
}
.PPI span.words {
    color: #999999;
}
.PPI span.transliterate {
    color: #9900FF;
}
.PPI span.substitute {
    color: #9900FF;
}
.PPI span.single {
    color: #999999;
}
.PPI span.regex {
    color: #9900FF;
}
.PPI span.pragma {
    color: #990000;
}
.PPI span.pod {
    color: #008080;
}
.PPI span.operator {
    color: #DD7700;
}
.PPI span.number {
    color: #990000;
}
.PPI span.match {
    color: #9900FF;
}
.PPI span.magic {
    color: #0099FF;
}
.PPI span.literal {
    color: #999999;
}
.PPI span.line_number {
    color: #666666;
}
.PPI span.keyword {
    color: #0000FF;
}
.PPI span.interpolate {
    color: #999999;
}
.PPI span.double {
    color: #999999;
}
.PPI span.core {
    color: #FF0000;
}
.PPI span.comment {
    color: #008080;
}
.PPI span.cast {
    color: #339999;
}
 
 
/* Copyright (c) 2005-2006 ActiveState Software Inc.
 *
 * Styles generated by ActiveState::Scineplex.
 *
 */
 
.SCINEPLEX span.comment {
  color:#ff0000;
  font-style: italic;
}
 
.SCINEPLEX span.default {
}
   
.SCINEPLEX span.keyword {
  color:#0099ff;
}
   
.SCINEPLEX span.here_document {
  color:#009933;
  font-weight: bold;   
}
 
.SCINEPLEX span.number {
  color:#8b0000;
  font-weight: bold;   
}
   
.SCINEPLEX span.operator {
  color:#0000ff;
  font-weight: bold;   
}
   
.SCINEPLEX span.regex {
  color:#c86400;
}
   
.SCINEPLEX span.string {
  color:#009933;
  font-weight: bold;   
}
   
.SCINEPLEX span.variable {
  color:0;
}
  </style>
  ~;
}


1;