package RapidApp::Web1RenderContext;

our %XTYPE_RENDER_METHODS= ();
sub registerXtypeRenderFunction {
	my ($unused, $xtype, $code)= @_;
	defined $XTYPE_RENDER_METHODS{$xtype}
		and warn "Render fn for xtype $xtype being overridden at ".sprintf('%s [%s line %s]',caller);
	$XTYPE_RENDER_METHODS{$xtype}= $code;
}

use Moose;
use RapidApp::Include 'perlutil';

has '_css_files' => ( is => 'rw', isa => 'HashRef', default => sub {{}} );
has '_js_files'  => ( is => 'rw', isa => 'HashRef', default => sub {{}} );
has '_header_extra' => ( is => 'rw', isa => 'ArrayRef', default => sub {[]} );

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
	my ($self, $text)= @_;
	push @{$self->_header_extra}, $text;
}

sub getHeaderLiteral {
	my $self= shift;
	return join("\n", @{$self->_header_extra});
}

sub render {
	my ($self, $extCfg)= @_;
	my @result;
	try {
		my $renderFn;
		if (blessed($extCfg) && ($renderFn= $extCfg->can('web1_render'))) {
			@result= $extCfg->$renderFn($self);
		}
		else {
			exists $extCfg->{xtype} or die RapidApp::Error->new("Config does not have an xtype, cannot continue");
			my $renderFn= $XTYPE_RENDER_METHODS{$extCfg->{xtype}};
			if (!defined $renderFn) {
				$renderFn= $self->can('render_xtype_'.$extCfg->{xtype});
				defined $renderFn or die RapidApp::Error->new("No render plugin defined for xtype '".$extCfg->{xtype}."'");
				__PACKAGE__->registerXtypeRenderFunction($extCfg->{xtype} => $renderFn);
			}
			@result= $self->$renderFn($extCfg);
		}
	}
	catch {
		# add some debugging info if possible
		blessed($_) && $_->can('data') and $_->data->{extCfg}= $extCfg;
		die $_; # rethrow
	};
	return @result;
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
	ref $obj or return escHtml("$obj")."<br/>\n";
	blessed $obj
		and return '<span class="dump-blessed-clsname">'.(ref $obj).'</span><div class="dump-blessed">', $self->_ref2html(reftype($obj), $obj), '</div>';
	return $self->_ref2html(ref ($obj), $obj);
}

sub _ref2html {
	my ($self, $refType, $obj)= @_;
	$refType eq 'HASH'
		and return $self->_hash2html($obj);
	$refType eq 'ARRAY'
		and return $self->_array2html($obj);
	$refType eq 'SCALAR'
		and return '<span class="dump-deref">[ref]</span>'.escHtml($$obj)."<br/>\n";
	$refType eq 'REF'
		and return '<span class="dump-deref">[ref]</span>', $self->_data2html($$obj);
	return escHtml("$obj")."<br/>\n";
}

sub _hash2html {
	my ($self, $obj)= @_;
	my @result= '<div class="dump-hash">';
	my $maxKeyLen= 0;
	my @keys= sort keys %$obj;
	for my $key (@keys) {
		$maxKeyLen= length($key) if length($key) > $maxKeyLen;
	}
	for my $key (sort keys %$obj) {
		push @result, sprintf("\n<span class='key'>%*s</span> ",-$maxKeyLen, $key), $self->_data2html($obj->{$key});
	}
	return @result, '</div>';
}

sub _array2html {
	my ($self, $obj)= @_;
	my @result= '<table class="dump-array">';
	my $i= 0;
	for my $item (@$obj) {
		push @result, sprintf("\n<tr><td class='key'>%d -</td><td>", $i++), $self->_data2html($item), '</td></tr>';
	}
	return @result, '</table>';
}

# DO NOT make immutable, to allow other packages to load plugins into this one
1;