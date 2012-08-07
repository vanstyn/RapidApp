package RapidApp::CatalystX::SimpleCAS::MimeUriResolver;
use Moose;

use strict;

use Email::MIME::CreateHTML::Resolver::LWP;
use RapidApp::Include qw(sugar perlutil);

has 'Cas' => (
	is => 'ro',
	isa => 'RapidApp::CatalystX::SimpleCAS::Controller',
	required => 1
);

has 'Resolver' => (
	is => 'ro',
	isa => 'Object',
	lazy => 1,
	default => sub {
		my $self = shift;
		return Email::MIME::CreateHTML::Resolver::LWP->new({ base => $self->base });
	}
);

has 'base' => (
	is => 'ro',
	isa => 'Str',
	required => 1
);


sub get_resource {
	my $self = shift;
	my ($uri) = @_;
	
	my ($content,$filename,$mimetype,$xfer_encoding);
	
	my $Content = $self->Cas->uri_find_Content($uri);
	if($Content) {
		$content = $Content->content;
		$filename = $Content->MIME->filename(1);
		$mimetype = $Content->MIME->content_type;
		$xfer_encoding = $Content->MIME->header('Content-Transfer-Encoding');
	}
	else {
		($content,$filename,$mimetype,$xfer_encoding) = $self->Resolver->get_resource(@_);
	}
	#scream($Content);
	
	#scream([$uri,$checksum,$fname]);
	
	
	
	#need this for dokuwiki images to show up:
	#$xfer_encoding = 'base64';
	
	return ($content,$filename,$mimetype,$xfer_encoding);
}


1;