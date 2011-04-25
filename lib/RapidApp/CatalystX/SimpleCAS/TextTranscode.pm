package RapidApp::CatalystX::SimpleCAS::TextTranscode;
our $VERSION = '0.01';
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use RapidApp::Include 'sugar';
use Encode;
use HTML::Encoding 'encoding_from_html_document', 'encoding_from_byte_order_mark';

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

1;
