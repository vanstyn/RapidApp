package RapidApp::CatalystX::SimpleCAS::TextTranscode;
our $VERSION = '0.01';
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use RapidApp::Include qw(sugar perlutil);
use Encode;
use HTML::Encoding 'encoding_from_html_document', 'encoding_from_byte_order_mark';
use HTML::TokeParser::Simple;
use Try::Tiny;
use Email::MIME;
use CSS::Simple;
use String::Random;


my $ISOLATE_CSS_RULE = '@import "/static/rapidapp/css/CssIsolation.css";';

sub transcode_html: Local  {
	my ($self, $c) = @_;
	
	my $upload = $c->req->upload('Filedata') or die "no upload object";

	my $src_text = $self->normaliaze_rich_content($c,$upload->slurp,$upload->filename);
	
	my $rct= $c->stash->{requestContentType};
	if ($rct eq 'JSON' || $rct eq 'text/x-rapidapp-form-response') {
		$c->stash->{json}= { success => \1, content => $src_text };
		return $c->forward('View::RapidApp::JSON');
	}
	
	# find out what encoding the user wants, defaulting to utf8
	my $dest_encoding= ($c->req->params->{dest_encoding} || 'utf-8');
	my $out_codec= find_encoding($dest_encoding) or die usererr "Unsupported encoding: $dest_encoding";
	my $dest_octets= $out_codec->encode($src_text);
	
	# we need to set the charset here so that catalyst doesn't try to convert it further
	$c->res->content_type('text/html; charset='.$dest_encoding);
	return $c->res->body($dest_octets);
}

sub generate_mhtml_download: Local {
	my ($self, $c) = @_;
	my $html = $c->req->params->{html} or die "No html content supplied";
	
	# 'filename' param is optional and probably not supplied
	$html = $self->normaliaze_rich_content($c,$html,$c->req->params->{filename});
	
	my $filename = $self->get_strip_orig_filename(\$html) || 'content.mht';
	my $content = $self->html_to_mhtml($c,$html);
	$filename =~ s/\"/\'/g; #<-- convert any " characters
	my $disposition = 'attachment;filename="' . $filename . '"';
	my $type = 'text/html; charset=utf-8';
	
	$c->response->header('Content-Type' => $type);
	$c->response->header('Content-Disposition' => $disposition);
	return $c->res->body( $content );
}
	

# extracts filename previously embedded by normaliaze_rich_content in html comment
sub get_strip_orig_filename {
	my $self = shift;
	my $htmlref = shift;
	return undef unless (ref $htmlref);
	
	$$htmlref =~ /(\/\*----ORIGINAL_FILENAME:(.+)----\*\/)/;
	my $comment = $1 or return undef;
	my $filename = $2 or return undef;
	
	# strip comment:
	$$htmlref =~ s/\Q${comment}\E//;
	
	return  $filename;
}


sub html_to_mhtml {
	my $self = shift;
	my $c = shift;
	my $html = shift;
	
	my $style = $self->parse_html_get_styles(\$html,1);
	
	# strip isolate css import rule:
	$style =~ s/\Q$ISOLATE_CSS_RULE\E//g;
	
	#scream_color(BLACK.ON_YELLOW,$ISOLATE_CSS_RULE,$style);
	
	if($style) {
		my $Css = CSS::Simple->new;
		$Css->read({ css => $style });
		
		#scream_color(BLACK.ON_RED,$Css->get_selectors);
		
		# undo the cas selector wrap applied during Load Html:
		foreach my $selector ($Css->get_selectors) {
			my $new_selector = $selector;
			if($selector =~ /^\#cas\-selector\-wrap\-\w+$/){
				$new_selector = 'body';
			}
			else {
				my @parts = split(/\s+/,$selector);
				my $first = shift @parts;
				next unless ($first =~ /^\#cas\-selector\-wrap\-/);
				$new_selector = join(' ',@parts);
			}
			$Css->modify_selector({
				selector => $selector,
				new_selector => $new_selector
			});
		}
		
		$style = $Css->write;
	}
	
	return $c->template_render('templates/rapidapp/xhtml_document.tt',{
		style => $style, 
		body => $html
	});
}


sub normaliaze_rich_content {
	my $self = shift;
	my $c = shift;
	my $src_octets = shift;
	my $filename = shift;
	
	my $content;
	
	# Try to determine what text encoding the file content came from, and then detect if it 
	# is MIME or HTML.
	#
	# Note that if the content came from a file upload/post an encode/decode phase happened 
	#   during the HTTP transfer of this file, but it should have been taken care of by Catalyst 
	#   and now we have the original file on disk in its native 8-bit encoding.

	# If MIME:
	my $MIME = try{Email::MIME->new($src_octets)};
	if($MIME && $MIME->subparts) {
		$content = $self->convert_from_mhtml($c,$MIME);
	}
	# If HTML:
	else {
		my $src_encoding= encoding_from_html_document($src_octets) || 'utf-8';
		my $in_codec= find_encoding($src_encoding) or die "Unsupported encoding: $src_encoding";
		$content = (utf8::is_utf8($src_octets)) ? $src_octets : $in_codec->decode($src_octets);
	}
	# TODO: Detect other content types and add fallback logic
	
	$content = $self->parse_html_get_style_body(\$content);
	$self->convert_data_uri_scheme_links($c,\$content);
	
	# Use style tags just as a safe place to store the original filename
	# (switched to this after having issues with html comments)
	$content = '<style>/*----ORIGINAL_FILENAME:' .
		$filename .
	'----*/</style>' . "\n" . $content if ($filename);

	return $content;
}


sub convert_from_mhtml {
	my $self = shift;
	my $c = shift;
	my $MIME = shift;

	my ($SubPart) = $MIME->subparts or return;
	
	## -- Check for and remove extra outer MIME wrapper (exists in actual MIME EMails):
	$MIME = $SubPart if (
		$SubPart->content_type &&
		$SubPart->content_type =~ /multipart\/related/
	);
	## --
	
	my ($MainPart) = $MIME->subparts or return;
	my $html = $MainPart->body_str;
	my $base_path = $self->parse_html_base_href(\$html) || $self->get_mime_part_base_path($MainPart);
	
	my %ndx = ();
	$MIME->walk_parts(sub{ 
		my $Part = shift;
		return if ($Part == $MIME || $Part == $MainPart); #<-- ignore the outer and main/body parts
		
		my $content_id = $Part->header('Content-ID');
		if ($content_id) {
			$ndx{'cid:' . $content_id} = $Part;
			$content_id =~ s/^\<//;
			$content_id =~ s/\>$//;
			$ndx{'cid:' . $content_id} = $Part;
		}
		
		my $content_location = $Part->header('Content-Location');
		if($content_location) {
			$ndx{$content_location} = $Part;
			if($base_path) {
				$content_location =~ s/^\Q$base_path\E//;
				$ndx{$content_location} = $Part;
			}
		}
	});
	
	$self->convert_mhtml_links_parts($c,\$html,\%ndx);
	return $html;
}

# Try to extract the 'body' from html to prevent causing DOM/parsing issues on the client side
sub parse_html_get_style_body {
	my $self = shift;
	my $htmlref = shift;
	
	my $body = $self->parse_html_get_body($htmlref) or return $$htmlref;
	my $style = $self->parse_html_get_styles($htmlref);
	
	my $auto_css_pre = 'cas-selector-wrap-';
	my $auto_css_id = $auto_css_pre . String::Random->new->randregex('[a-z0-9]{8}');
	
	if($style) {
		my $Css = CSS::Simple->new;
		$Css->read({ css => $style });
		
		#scream_color(BLACK.ON_RED,$Css->get_selectors);
		
		foreach my $selector ($Css->get_selectors) {
			my @parts = split(/\s+/,$selector);
			# strip selector wrap from previous content processing (when the user imports + 
			# exports + imports multiple times)
			shift @parts if ($parts[0] =~ /^\#${auto_css_pre}/);
			unshift @parts, '#' . $auto_css_id;
			pop @parts if (lc($selector) eq 'body'); #<-- any 'body' selectors are replaced by the new div wrap below
			
			$Css->modify_selector({
				selector => $selector,
				new_selector => join(' ',@parts)
			});
		}
		
		$style = $Css->write;
	}

	if ($style) {
		# minify:
		$style =~ s/\r?\n/ /gm;
		$style =~ s/\s+/ /gm;
		$style = "\n<style type=\"text/css\">\n$style\n</style>";
	}
	
	$style ||= '';
	$style = "\n" .	'<style type="text/css">' . "\n" .
		"   $ISOLATE_CSS_RULE\n" .
		'</style>' . $style . "\n";

	return '<div class="isolate" id="' . $auto_css_id . '">' . "\n" .
		$body . "\n" . 
	'</div>' . "\n$style";		
}


# Try to extract the 'body' from html to prevent causing DOM/parsing issues on the client side
# Also strip html comments
sub parse_html_get_body {
	my $self = shift;
	my $htmlref = shift;
	my $parser = HTML::TokeParser::Simple->new($htmlref);
	my $in_body = 0;
	my $inner = '';
	while (my $tag = $parser->get_token) {
		last if ($in_body && $tag->is_end_tag('body'));
		$inner .= $tag->as_is if ($in_body && !$tag->is_comment);
		$in_body = 1 if ($tag->is_start_tag('body'));
	};
	return undef if ($inner eq '');
	return $inner;
}

sub parse_html_get_styles {
	my $self = shift;
	my $htmlref = shift;
	my $strip = shift;
	my $parser = HTML::TokeParser::Simple->new($htmlref);
	my $in_style = 0;
	my $styles = '';
	my $newhtml = '';
	while (my $tag = $parser->get_token) {
		$in_style = 0 and next if ($tag->is_end_tag('style'));
		$styles .= $tag->as_is and next if ($in_style);
		$in_style = 1 and next if ($tag->is_start_tag('style'));
		$newhtml .= $tag->as_is if($strip && !$tag->is_tag('style'));
	};
	return undef if ($styles eq '');
	
	$$htmlref = $newhtml if ($strip);
	
	# Pull out html comment characters, ignored in css, but can interfere with CSS::Simple (rare cases)
	$styles =~ s/\<\!\-\-//g;
	$styles =~ s/\-\-\>//g;
	
	return $styles;
}



# Extracts the base file path from the 'base' tag of the MHTML content
sub parse_html_base_href {
	my $self = shift;
	my $htmlref = shift;
	my $parser = HTML::TokeParser::Simple->new($htmlref);
	while (my $tag = $parser->get_tag) {
		if($tag->is_tag('base')){
			my $url = $tag->get_attr('href') or next;
			return $url;
		}
	};
	return undef;
}

# alternative method to identify a base path from a Mime Part
sub get_mime_part_base_path {
	my $self = shift;
	my $Part = shift;
	
	my $content_location = $Part->header('Content-Location') or return undef;
	my @parts = split(/\//,$content_location);
	my $filename = pop @parts;
	my $path = join('/',@parts) . '/';
	
	return $path;
}


sub convert_mhtml_links_parts {
	my $self = shift;
	my $c = shift;
	my $htmlref = shift;
	my $part_ndx = shift;
	
	die "convert_mhtml_links_parts(): Invalid arguments!!" unless (ref $part_ndx eq 'HASH');
	
	my $parser = HTML::TokeParser::Simple->new($htmlref);
	
	my $substitutions = {};
	
	while (my $tag = $parser->get_tag) {
		next if($tag->is_tag('base')); #<-- skip the 'base' tag which we parsed earlier
		for my $attr (qw(src href)){
			my $url = $tag->get_attr($attr) or next;
			my $Part = $part_ndx->{$url} or next;
			my $cas_url = $self->mime_part_to_cas_url($c,$Part) or next;
			
			my $as_is = $tag->as_is;
			$tag->set_attr( $attr => $cas_url );
			$substitutions->{$as_is} = $tag->as_is;
		}
	}
	
	foreach my $find (keys %$substitutions) {
		my $replace = $substitutions->{$find};
		$$htmlref =~ s/\Q$find\E/$replace/gm;
	}
}



# See http://en.wikipedia.org/wiki/Data_URI_scheme
sub convert_data_uri_scheme_links {
	my $self = shift;
	my $c = shift;
	my $htmlref = shift;
	
	my $parser = HTML::TokeParser::Simple->new($htmlref);
	
	my $substitutions = {};
	
	while (my $tag = $parser->get_tag) {
	
		my $attr;
		if($tag->is_tag('img')) {
			$attr = 'src';
		}
		elsif($tag->is_tag('a')) {
			$attr = 'href';
		}
		else {
			next;
		}
		
		my $url = $tag->get_attr($attr) or next;
		
		# Support the special case where the src value is literal base64 data:
		if ($url =~ /^data:/) {
			my $newurl = $self->embedded_src_data_to_url($c,$url);
			$substitutions->{$url} = $newurl if ($newurl);
		}
	}
	
	foreach my $find (keys %$substitutions) {
		my $replace = $substitutions->{$find};
		$$htmlref =~ s/\Q$find\E/$replace/gm;
	}
}

sub embedded_src_data_to_url {
	my $self = shift;
	my $c = shift;
	my $url = shift;
	
	my $Cas = $c->controller('SimpleCAS');
	
	my ($pre,$content_type,$encoding,$base64_data) = split(/[\:\;\,]/,$url);
	
	# we only know how to handle base64 currently:
	return undef unless (lc($encoding) eq 'base64');
	
	my $checksum = try{$Cas->Store->add_content_base64($base64_data)}
		or return undef;
	
	# TODO: The Url path should be supplied by SimpleCas!! I seem to recall there was
	# some issue during the original development that led me to put it in the javascript
	# side as a quick hack. Need to revisit and properly abstract
	return "/simplecas/fetch_content/$checksum";
}

sub mime_part_to_cas_url {
	my $self = shift;
	my $c = shift;
	my $Part = shift;
	
	my $Cas = $c->controller('SimpleCAS');
	
	my $data = $Part->body;
	my $filename = $Part->filename(1);
	my $checksum = $Cas->Store->add_content($data) or return undef;
	
	return "/simplecas/fetch_content/$checksum/$filename";
}

1;