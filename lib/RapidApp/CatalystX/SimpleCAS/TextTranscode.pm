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

sub transcode_html: Local  {
	my ($self, $c) = @_;
	
	# Get the file text and determine what encoding it came from.
	# Note that an encode/decode phase happened during the HTTP transfer of this file, but
	#   it should have been taken care of by Catalyst and now we have the original
	#   file on disk in its native 8-bit encoding.
	my $upload = $c->req->upload('Filedata') or die "no upload object";
	my $src_octets = $upload->slurp;
	my $src_encoding= encoding_from_html_document($src_octets) || 'utf-8';
	my $in_codec= find_encoding($src_encoding) or die "Unsupported encoding: $src_encoding";
	my $src_text= $in_codec->decode($src_octets);
	
	$self->convert_data_uri_scheme_links($c,\$src_text);
	
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



1;
