package RapidApp::Web1RenderContext;


use Moose;
use RapidApp::Include 'perlutil';

has '_css_files' => ( is => 'rw', isa => 'HashRef', default => sub {{}} );
has '_js_files'  => ( is => 'rw', isa => 'HashRef', default => sub {{}} );
has 'header_fragments' => ( is => 'rw', isa => 'ArrayRef', default => sub {[]} );
has 'body_fragments' => ( is => 'rw', isa => 'ArrayRef', default => sub {[]} );

sub BUILD {
	my $self= shift;
}

sub incCSS {
	my ($self, $cssUrl)= @_;
	$self->_css_files->{$cssUrl}= undef;
}

sub getCssIncludeList {
	my $self= shift;
	return keys %{$self->_css_files};
}

sub incJS {
	my ($self, $jsUrl)= @_;
	$self->_js_files->{$jsUrl}= undef;
}

sub getJsIncludeList {
	my $self= shift;
	return keys %{$self->_js_files};
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

sub data2html {
	my ($self, $obj)= @_;
	$self and $self->incCSS('/static/rapidapp/css/data2html.css');
	return _data2html(@_);
}

sub _data2html {
	my ($self, $obj)= @_;
	if (!ref $obj) {
		$self->write(escHtml("$obj")."<br/>\n");
	} elsif (blessed $obj) {
		$self->write('<span class="dump-blessed-clsname">'.(ref $obj).'</span><div class="dump-blessed">');
		$self->_ref2html(reftype($obj), $obj),
		$self->write('</div>');
	} else {
		$self->_ref2html(ref ($obj), $obj);
	}
}

sub _ref2html {
	my ($self, $refType, $obj)= @_;
	if ($refType eq 'HASH') {
		$self->_hash2html($obj);
	} elsif ($refType eq 'ARRAY') {
		$self->_array2html($obj);
	} elsif ($refType eq 'SCALAR') {
		$self->write('<span class="dump-deref">[ref]</span>'.escHtml($$obj)."<br/>\n");
	} elsif ($refType eq 'REF') {
		$self->write('<span class="dump-deref">[ref]</span>');
		$self->_data2html($$obj);
	} else {
		$self->write(escHtml("$obj")."<br/>\n");
	}
}

sub _hash2html {
	my ($self, $obj)= @_;
	$self->write('<div class="dump-hash">');
	my $maxKeyLen= 0;
	my @keys= sort keys %$obj;
	for my $key (@keys) {
		$maxKeyLen= length($key) if length($key) > $maxKeyLen;
	}
	for my $key (sort keys %$obj) {
		$self->write(sprintf("\n<span class='key'>%*s</span> ",-$maxKeyLen, $key));
		$self->_data2html($obj->{$key});
	}
	$self->write('</div>');
}

sub _array2html {
	my ($self, $obj)= @_;
	$self->write('<table class="dump-array">');
	my $i= 0;
	for my $item (@$obj) {
		$self->write(sprintf("\n<tr><td class='key'>%d -</td><td>", $i++));
		$self->_data2html($item);
		$self->write('</td></tr>');
	}
	$self->write('</table>');
}

# DO NOT make immutable, to allow other packages to load plugins into this one
1;