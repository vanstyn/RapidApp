package RapidApp::CatalystX::SimpleCAS::Controller;
our $VERSION = '0.01';
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use RapidApp::CatalystX::SimpleCAS::Content;
use RapidApp::CatalystX::SimpleCAS::Store::File;
use JSON::PP;

has 'store_class' => ( is => 'ro', default => 'RapidApp::CatalystX::SimpleCAS::Store::File' );
has 'store_path' => ( is => 'ro', required => 1 );

has 'Store' => (
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $class = $self->store_class;
		return $class->new(
			store_dir => $self->store_path
		);
	}
);

sub Content {
	my $self = shift;
	my $checksum = shift;
	return RapidApp::CatalystX::SimpleCAS::Content->new(
		Store		=> $self->Store,
		checksum	=> $checksum
	);
}



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
		checksum => $checksum,
		height => $height,
		width => $width
	};
	
	#$c->response->header('Content-Type' => 'text/plain');
	
	#return $c->res->body('{"stupid":"asshole"}');
	return $c->res->body(JSON::PP::encode_json($packet));
}



1;
