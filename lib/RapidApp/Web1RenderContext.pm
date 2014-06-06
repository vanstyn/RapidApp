package RapidApp::Web1RenderContext;
use Moose;
use RapidApp::Include 'perlutil';
use Scalar::Util 'refaddr';

use RapidApp::Web1RenderContext::RenderFunction;
use RapidApp::Web1RenderContext::RenderHandler;
use RapidApp::Web1RenderContext::Renderer;

=head1 NAME

RapidApp::Web1RenderContext

=head1 SYNOPSIS

  my $cx= RapidApp::Web1RenderContext->new();
  $cx->render($data);
  $cx->write("<div class='copyright'>Copyright (c) 2042 Our Company</div>");
  
  my $html= '<html><head>';
  for my $jsFile (@{$cx->getJsIncludeList) {
    $html .= '<script type="text/javascript" src="' . $jsFile . '"></script>';
  }
  for my $cssFile (@{$cx->getCssIncludeList) {
    $html .= '<link rel="stylesheet" type="text/css" href="' . $cssFile . '" />';
  }
  $html .= $cx->getHeaderLiteral . '</head><body>';
  $html .= $cx->getBody;
  $html .= '</body></html>';

  # to re-use the render context, you need to clear it
  $cx->clear();

=head1 DESCRIPTION

This module facilitates writing html fragments in short bursts and later joining them
while also building up a list of javascript and css files which are required.

Note that none of these functions *return* html, they collect it within the context, to
be joined later.

When you are done, you can build a proper HTML page from it.

This module also has a renderer, which can be set to any renderer of your choice.

There are also a number of handy utility methods, like "data2html".

=cut

our $DEFAULT_RENDERER= RapidApp::Web1RenderContext::RenderFunction->new(\&data2html);

has '_css_files' => ( is => 'rw', isa => 'HashRef', default => sub {{}} );
has '_js_files'  => ( is => 'rw', isa => 'HashRef', default => sub {{}} );
has 'header_fragments' => ( is => 'rw', isa => 'ArrayRef', default => sub {[]} );
has 'body_fragments' => ( is => 'rw', isa => 'ArrayRef', default => sub {[]} );
has 'renderer'  => ( is => 'rw', isa => 'RapidApp::Web1RenderContext::Renderer', lazy => 1, default => sub { $DEFAULT_RENDERER });

# free-form parameters for adjusting rendering
has 'params' => ( is => 'rw', isa => 'HashRef', default => sub {{}} );

sub BUILD {
	my $self= shift;
}

sub incCSS {
	my ($self, $cssUrl, $order)= @_;
	$order ||= 0;
	exists $self->_css_files->{$cssUrl} && $self->_css_files->{$cssUrl} ne $order
		and warn "Conflicting priority for file: $cssUrl";
	$self->_css_files->{$cssUrl}= $order;
}

sub getCssIncludeList {
	my $self= shift;
	my $files= $self->_css_files;
	return sort { $files->{$a} <=> $files->{$b} } keys %$files;
}

sub getInlineCss {
	my $self= shift;
	my $app= RapidApp::ScopedGlobals->catalystClass;
	my $log= RapidApp::ScopedGlobals->log;
	my $params= ref $_[0] eq 'HASH'? $_[0] : { %_ };
	my $path= $params->{path} || [ $app->config->{root} ];
	
	my @cssFiles= $self->getCssIncludeList;
	my @text= ();
	for my $fname (@cssFiles) {
		try {
			my $filePath= $fname;
			my $i= 0;
			while (! -e $filePath) {
				$i <= $#$path or die "file not found";
				$filePath= $path->[$i++].'/'.$fname;
			}
			open (my $fd, "<:encoding(UTF-8)", $filePath) or die $!;
			local $/= undef;
			my $content= <$fd>;
			push @text, $content;
		}
		catch {
			$log->error("Cannot inline $fname: ".$_);
		};
	}
	return join "\n", @text;
}

sub inlineCssFiles {
	my $self= shift;
	$self->addHeaderLiteral("<style type='text/css'>\n".$self->getInlineCss(@_)."\n</style>\n");
	%{$self->_css_files}= ();
}

sub incJS {
	my ($self, $jsUrl, $order)= @_;
	$order ||= 0;
	exists $self->_js_files->{$jsUrl} && $self->_js_files->{$jsUrl} ne $order
		and warn "Conflicting priority for file: $jsUrl";
	$self->_js_files->{$jsUrl}= $order;
}

sub getJsIncludeList {
	my $self= shift;
	my $files= $self->_js_files;
	return sort { $files->{$a} <=> $files->{$b} } keys %$files;
}

sub addHeaderLiteral {
	my ($self, @text)= @_;
	push @{$self->header_fragments}, @text;
}

sub getHeaderLiteral {
	my $self= shift;
	return join("\n", @{$self->header_fragments});
}

sub getBody {
	my $self= shift;
	return join('', @{$self->body_fragments});
}

sub clear {
	my $self= shift;
	%{$self->_css_files}= ();
	%{$self->_js_files}= ();
	@{$self->header_fragments}= ();
	@{$self->body_fragments}= ();
}

sub clearBody {
	my $self= shift;
	@{$self->body_fragments}= ();
}

sub write {
	my $self= shift;
	push @{$self->body_fragments}, @_;
}

sub escHtml {
	my ($self, $text)= @_;
	scalar(@_) > 1 or $text= $self; # can be called as either object, package, or plain function
	$text =~ s/&/&amp;/g;
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;
	$text =~ s/"/&quot;/g;
	return $text;
}

sub render {
	my ($self, $data)= @_;
	return $self->renderer->renderAsHtml($self, $data);
}

sub data2html {
	my ($self, $obj)= @_;
	$self and $self->incCSS('/static/rapidapp/css/data2html.css');
	return _data2html(@_, {});
}

sub _data2html {
	my ($self, $obj, $seenSet)= @_;
	if (!ref $obj) {
		$self->write((defined $obj? escHtml("'$obj'") : "undef")."<br />\n");
	} elsif (blessed $obj) {
		$self->write('<span class="dump-blessed-clsname">'.(ref $obj).'</span><div class="dump-blessed">');
		
		# NEVER dump our own object... hehe  (grows infinitely)
		# comparing  objects with operator overloads can get hairy, so just ignore all Web1RenderContexts
		if (ref $obj eq 'Web1RenderContext') {
			$self->write(escHtml("$obj"));
		}
		else {
			$self->_ref2html(reftype($obj), $obj, $seenSet),
		}
		$self->write('</div>');
	} else {
		$self->_ref2html(ref ($obj), $obj, $seenSet);
	}
}

sub _ref2html {
	my ($self, $refType, $obj, $seenSet)= @_;
	if ($refType ne 'SCALAR' && exists $seenSet->{refaddr $obj}) {
		return $self->write("(seen previously) $obj<br />\n");
	}
	$seenSet->{refaddr $obj}= undef;
	if ($refType eq 'HASH') {
		$self->_hash2html($obj, $seenSet);
	} elsif ($refType eq 'ARRAY') {
		$self->_array2html($obj, $seenSet);
	} elsif ($refType eq 'SCALAR') {
		$self->write('<span class="dump-deref">[ref]</span>'.escHtml($$obj)."<br/>\n");
	} elsif ($refType eq 'REF') {
		$self->write('<span class="dump-deref">[ref]</span>');
		$self->_data2html($$obj, $seenSet);
	} else {
		$self->write(escHtml("$obj")."<br />\n");
	}
}

sub _hash2html {
	my ($self, $obj, $seenSet)= @_;
	$self->write('<div class="dump-hash">');
	my $maxKeyLen= 0;
	my @keys= sort keys %$obj;
	for my $key (@keys) {
		$maxKeyLen= length($key) if length($key) > $maxKeyLen;
	}
	for my $key (sort keys %$obj) {
		$self->write(sprintf("\n<span class='key'>%*s</span> ",-$maxKeyLen, $key));
		$self->_data2html($obj->{$key}, $seenSet);
	}
	$self->write('</div>');
}

sub _array2html {
	my ($self, $obj, $seenSet)= @_;
	$self->write('<table class="dump-array">');
	my $i= 0;
	for my $item (@$obj) {
		$self->write(sprintf("\n<tr><td class='key'>%d -</td><td>", $i++));
		$self->_data2html($item, $seenSet);
		$self->write('</td></tr>');
	}
	$self->write('</table>');
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
