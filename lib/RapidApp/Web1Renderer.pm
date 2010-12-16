package RapidApp::Web1Renderer;

use Moose;

with 'RapidApp::Web1Renderer::R_appstoreform2';

has '_css_files' => ( is => 'rw', isa => 'HashRef', default => sub {{}} );
has '_js_files'  => ( is => 'rw', isa => 'HashRef', default => sub {{}} );
has '_header_extra' => ( is => 'rw', isa => 'ArrayRef', default => sub {[]} );
has '_renderFnCache' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );

sub BUILD {
	my $self= shift;
}

sub incCSS {
	my ($self, $cssUrl)= @_;
	$self->_css_files->{$cssFile}= undef;
}

sub incJS {
	my ($self, $jsUrl)= @_;
	$self->_js_files->{$jsFile}= undef;
}

sub addHeaderLiteral {
	my ($self, $text)= @_;
	push @{$self->_header_extra}, $text;
}

sub render {
	my ($self, $extCfg)= @_;
	my $result;
	try {
		exists $extCfg->{xtype} or die RapidApp::Error->new("Config does not have an xtype, cannot continue");
		my $renderFn= $self->_renderFnCache->{$extCfg->{xtype}};
		if (!defined $renderFn) {
			$renderFn= $self->can('render_'.$extCfg->{xtype});
			defined $renderFn or die RapidApp::Error->new("No render plugin defined for xtype '".$extCfg->{xtype}."'");
			$self->_renderFnCache->{$extCfg->{xtype}}= $renderFn;
		}
		$result= $self->$renderFn($extCfg);
	}
	catch {
		# add some debugging info if possible
		blessed($_) && $_->can('data') and $_->data->{extCfg=>$extCfg};
		die $_; # rethrow
	};
	return $result;
}

sub escHtml {
	my ($self, $text)= @_;
	$text =~ s/&/&amp;/g;
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;
	$text =~ s/"/&quot;/g;
	return $text;
}

sub data2html {
	my ($self, $obj)= @_;
	ref $obj 
	return '<pre>', $self->escHtml(Dumper($obj)), '</pre>';
}

1;