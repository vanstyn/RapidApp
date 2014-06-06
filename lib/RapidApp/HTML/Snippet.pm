package RapidApp::HTML::Snippet;
use Moose;

use RapidApp::Include qw(sugar perlutil);

use RapidApp::HTML::Snippet::TagProcessor;

use CSS::Inliner;
use CSS::Tiny;
use HTML::TokeParser::Simple;
use String::Random;

has 'html' => ( is => 'rw', isa => 'Str', required => 1 );
has 'css' => ( is => 'rw', isa => 'Maybe[Str]', default => undef );
has 'Parser' => ( is => 'rw',	isa => 'HTML::TokeParser::Simple' );
has 'current_token' => ( is => 'rw', isa => 'Maybe[Object]', default => undef );

has 'expand_stylesheet_links' => ( is => 'ro', isa => 'Bool', default => 1 );

has 'store_tags' => (
	is => 'ro',
	isa => 'HashRef[Str]',
	default => sub {{
		style		=> '',
		head		=> '',
		body		=> ''
	}}
);

has 'store_tags_opened' => (
	is => 'ro',
	isa => 'HashRef[Bool]',
	default => sub {{}}
);

has 'strip_tags' => (
	is => 'ro',
	isa => 'HashRef[Bool]',
	default => sub {{
		style		=> 1,
	}}
);


has 'parent_tags' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );

before 'current_token_content' => sub {
	my $self = shift;
	return unless ($self->current_token->is_start_tag);
	my $type = $self->current_token->get_tag;
	$self->parent_tags->{$type}++;
};

after 'current_token_content' => sub {
	my $self = shift;
	return unless ($self->current_token->is_end_tag);
	my $type = $self->current_token->get_tag;
	$self->parent_tags->{$type}-- if ($self->parent_tags->{$type} > 0);
};


has 'tag_processors' => ( 
	is => 'ro', 
	traits => [ 'Array' ],
	isa => 'ArrayRef[HashRef]', 
	default => sub {[]},
	handles => {
		all_tag_processors => 'elements'
	}
);

has 'Processors' => (
	is => 'ro',
	traits => [ 'Array' ],
	isa => 'ArrayRef[RapidApp::HTML::Snippet::TagProcessor]',
	default => sub {[]},
	handles => {
		add_Processor => 'push',
		all_Processors => 'elements'
	}
);

has 'Processors_hash' => (
	is => 'ro',
	isa => 'HashRef[ArrayRef[RapidApp::HTML::Snippet::TagProcessor]]',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $hash = {};
		
		foreach my $Processor ($self->all_Processors) {
			$hash->{$Processor->tag} = [] unless (defined $hash->{$Processor->tag});
			push @{$hash->{$Processor->tag}}, $Processor;
		}
		
		return $hash;
	}
);


has 'active_Processors' => ( is => 'ro', isa => 'HashRef[RapidApp::HTML::Snippet::TagProcessor]', default => sub {{}} );

has 'wrap_snippet' => ( is => 'ro', isa => 'Bool', default => 0 );

has 'div_wrap_class' => (
	is => 'ro',
	isa => 'Str',
	lazy => 1,
	default => sub { 'snippet-wrap-' . String::Random->new->randregex('[a-z0-9A-Z]{8}') }
);

sub all_active_processors {
	my $self = shift;
	my @list = ();
	foreach my $k (keys %{$self->active_Processors}) {
		push @list, $self->active_Processors->{$k};
	}
	return @list;
}




sub BUILD {
	my $self = shift;
	
	foreach my $conf ($self->all_tag_processors) {
		$conf->{Snippet} = $self;
		$self->add_Processor(
			RapidApp::HTML::Snippet::TagProcessor->new($conf)
		);
	}
	
	$self->add_Processor(RapidApp::HTML::Snippet::TagProcessor->new({
		Snippet	=> $self,
		tag		=> 'link',
		single_token => 1,
		selector => sub {
			my $token = shift;
			return 1 if ($token->get_attr('href') and $token->get_attr('type') eq 'text/css');
			return 0;
		},
		processor => sub {
			my $proc = shift;
			my $token = shift;
			my $uri = $token->get_attr('href');
			my $content = $proc->Snippet->fetch_uri_content($uri);
			return undef unless ($content);
			
			$proc->Snippet->append_css($content);
			
			$content = '<style type="type/css">' . "\n" . 
				$content . 
			'</style>' . "\n";
		}
	})) if ($self->expand_stylesheet_links);
	
}


sub next_token {
	my $self = shift;
	
	$self->as_is_overload(undef);
	
	my $token = $self->Parser->get_token || return undef;
	$self->current_token($token);
	return $self->current_token;
}


has 'as_is_overload' => ( is => 'rw', isa => 'Maybe[Str]', default => undef );

sub current_token_as_is {
	my $self = shift;
	
	my $overload = $self->as_is_overload;
	if($overload) {
		$self->as_is_overload(undef);
		return $overload;
	}
	
	return $self->current_token->as_is;
}



sub current_token_content {
	my $self = shift;
	
	$self->call_Processors;
	
	my $nostore = '';
	if ($self->current_token->is_tag) {
		my $type = $self->current_token->get_tag;
		
		if (defined $self->store_tags->{$type}) {
			$self->store_tags_opened->{$type} = 1 if ($self->current_token->is_start_tag);
			$self->store_tags_opened->{$type} = 0 if ($self->current_token->is_end_tag);
			$nostore = $type;
		}
	}
	
	foreach my $type (keys %{$self->store_tags_opened}) {
		next unless ($self->store_tags_opened->{$type});
		$self->store_tags->{$type} .= $self->current_token_as_is unless ($nostore eq $type or $self->strip_current($type));
	}
		
	return $self->current_token_as_is unless ($self->strip_current);
	return '';
}

sub strip_current {
	my $self = shift;
	my $exclude = shift || '';
	foreach my $type (keys %{$self->strip_tags}) {
		next unless ($self->strip_tags->{$type});
		return 1 if ($self->parent_tags->{$type} and $exclude ne $type);
	}
	return 0;
}



sub call_Processors {
	my $self = shift;
	
	if ($self->current_token->is_start_tag) {
		my $type = $self->current_token->get_tag;
		if (defined $self->Processors_hash->{$type}) {
			foreach my $Processor (@{$self->Processors_hash->{$type}}) {
				my $output = $Processor->process;
				$self->as_is_overload($output) if ($output and ref(\$output) eq 'SCALAR' and length($output) > 1);
			}
		}
	}
	
	foreach my $Processor ($self->all_active_processors) {
		my $output = $Processor->process;
		$self->as_is_overload($output) if ($output and ref(\$output) eq 'SCALAR' and length($output) > 1);
	}
	
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
		#if ($self->current_token->is_start_tag('style')) {
		#	$self->append_css($self->get_inner_advance);
		#	next;
		#}
		$htmlout .= $self->current_token_content;
	}
	
	$self->append_css($self->store_tags->{style});
	
	return $self->html($htmlout);
}


sub processed_css {
	my $self = shift;
	
	return $self->css unless ($self->wrap_snippet);
	
	my $CSS = CSS::Tiny->read_string($self->css);
	
	foreach my $sel (keys %$CSS) {
		$CSS->{'div.' . $self->div_wrap_class . ' ' . $sel} = $CSS->{$sel};
		delete $CSS->{$sel};
	}
	
	return $CSS->write_string;
}




sub body_inner {
	my $self = shift;
	return $self->store_tags->{body} if (
		defined $self->store_tags->{body} and 
		$self->store_tags->{body} ne ''
	);
	return $self->html;
}

sub body_with_style {
	my $self = shift;
	my $string = 
		'<!DOCTYPE html>' . "\n" .
		'<style type="text/css">' . "\n" . 
			#$self->css . "\n" .
			$self->processed_css . "\n" .
		'</style>' . "\n";
		#$self->html;
		
		return $string . $self->body_inner unless ($self->wrap_snippet);
		
		return $string . '<div class="' . $self->div_wrap_class . '">' .
		
		$self->body_inner .
		
		'</div>';
}

sub body_with_style_inlined {
	my $self = shift;
	
	my $inliner = CSS::Inliner->new;
	$inliner->read({ html => $self->body_with_style });
	
	return $inliner->inlinify;
}

sub fetch_uri_content {
	my $self = shift;
	my $uri = shift;
	
	my $content = '';
	
	if (-f $uri) {
		open FILE, "< $uri" or return undef;
		while(<FILE>) {
			$content .= $_;
		}
		close FILE;
		return $content;
	}
	
	# TODO: LWP fetch:
}

1;

__END__


# Not currently used:
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
