package RapidApp::HTML::Snippet;
use Moose;

use RapidApp::Include qw(sugar perlutil);

use CSS::Inliner;
use HTML::TokeParser::Simple;

has 'html' => ( is => 'rw', isa => 'Str', required => 1 );
has 'css' => ( is => 'rw', isa => 'Maybe[Str]', default => undef );
has 'Parser' => ( is => 'rw',	isa => 'HTML::TokeParser::Simple' );
has 'current_token' => ( is => 'rw', isa => 'Maybe[Object]', default => undef );


sub BUILD {
	my $self = shift;
	
}


sub next_token {
	my $self = shift;
	my $token = $self->Parser->get_token || return undef;
	$self->current_token($token);
	
	
	print "              -> " . $self->current_token->get_tag . "\n" if ($self->current_token->is_start_tag);
	
	return $self->current_token;
}

sub next_as_is {
	my $self = shift;
	$self->next_token || return undef;
	return $self->current_token_content;
}


sub current_token_content {
	my $self = shift;
	return $self->current_token->as_is;
}








sub append_css {
	my $self = shift;
	my $css = shift;

	return $self->css( $self->css . "\n" . $css );
}


sub preprocess {
	my $self = shift;
	
	my $htmlref = \$self->html;
	
	my $htmlout = '';
	
	$self->Parser(HTML::TokeParser::Simple->new($htmlref));
	
	while ($self->next_token) {
		if ($self->current_token->is_start_tag('style')) {
			$self->append_css($self->get_inner_advance);
			next;
		}
		$htmlout .= $self->current_token_content;
	}
	
	print "reached end\n";
	
	return $self->html($htmlout);
}


sub get_inner_advance {
	my $self = shift;
	my $include_tag = shift;
	
	die 'Current token is not a start tag' unless ($self->current_token->is_start_tag);
	my $type = $self->current_token->get_tag;
	
	my $content = '';
	$content .= $self->current_token_content if ($include_tag);
	while ($self->next_token) {
		if ($self->current_token->is_end_tag) {
			die "Found end tag, but wrong type" unless ($self->current_token->is_end_tag($type));
			$content .= $self->current_token_content if ($include_tag);
			return $content;
		}
		elsif ($self->current_token->is_start_tag) {
			$content .= $self->get_inner_advance(1);
		}
		else {
			$content .= $self->current_token_content;
		}
	}
	die "Error: premature end of document";
}





1;
