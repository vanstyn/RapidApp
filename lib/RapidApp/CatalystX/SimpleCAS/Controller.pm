package RapidApp::CatalystX::SimpleCAS::Controller;
our $VERSION = '0.01';
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use RapidApp::CatalystX::SimpleCAS::Store::File;
use JSON::PP;

has 'Store' => (
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		return RapidApp::CatalystX::SimpleCAS::Store::File->new(
			store_dir => '/root/RapidApps/GreenSheet/file_cas'
		);
	}
);

sub fetch_content: Local {
    my ($self, $c, $checksum) = @_;
	
	unless($self->Store->content_exists($checksum)) {
		$c->res->body('Does not exist');
		return;
	}
	
	my $type = $self->Store->content_mimetype($checksum) or die "Error reading mime type";
	
	$c->response->header('Content-Type' => $type);
	$c->response->header('Content-Disposition' => 'inline;filename="' . $checksum . '"');
	return $c->res->body( $self->Store->fetch_content_fh($checksum) );
}


sub upload_content: Local  {
	my ($self, $c) = @_;

	my $upload = $c->req->upload('Filedata') or die "no upload object";
	my $checksum = $self->Store->add_content_file_mv($upload->tempname) or die "Failed to add content";
	
	return $c->res->body($checksum);
}


sub upload_image: Local  {
	my ($self, $c) = @_;

	my $upload = $c->req->upload('Filedata') or die "no upload object";
	my $checksum = $self->Store->add_content_file_mv($upload->tempname) or die "Failed to add content";
	
	my ($width,$height) = $self->Store->image_size($checksum);
	
	
	my $tag = '<img src="/simplecas/fetch_content/' . $checksum . '"';
	$tag .= ' width=' . $width . ' height=' . $height if ($width and $height);
	$tag .= '>';
	
	my $packet = {
		success => \1,
		img_tag => $tag
	};
	
	return $c->res->body(JSON::PP::encode_json($packet));
}



1;
