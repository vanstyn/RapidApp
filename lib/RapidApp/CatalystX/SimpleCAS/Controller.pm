package RapidApp::CatalystX::SimpleCAS::Controller;
our $VERSION = '0.01';
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use RapidApp::CatalystX::SimpleCAS::Content;
use RapidApp::CatalystX::SimpleCAS::Store::File;
use JSON::PP;
use MIME::Base64;
use Image::Resize;
use String::Random;

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
   my ($self, $c, $checksum, $filename) = @_;
	
	my $disposition = 'inline;filename="' . $checksum . '"';
	$disposition = 'attachment;filename=' . $filename if ($filename);
	
	unless($self->Store->content_exists($checksum)) {
		$c->res->body('Does not exist');
		return;
	}
	
	my $type = $self->Store->content_mimetype($checksum) or die "Error reading mime type";
	
	$c->response->header('Content-Type' => $type);
	$c->response->header('Content-Disposition' => $disposition);
	return $c->res->body( $self->Store->fetch_content_fh($checksum) );
}


sub upload_content: Local  {
	my ($self, $c) = @_;

	my $upload = $c->req->upload('Filedata') or die "no upload object";
	my $checksum = $self->Store->add_content_file_mv($upload->tempname) or die "Failed to add content";
	
	return $c->res->body($checksum);
}


sub upload_image: Local  {
	my ($self, $c, $maxwidth) = @_;

	my $upload = $c->req->upload('Filedata') or die "no upload object";
	my $checksum = $self->Store->add_content_file_mv($upload->tempname) or die "Failed to add content";
	
	my ($type,$subtype) = split(/\//,$upload->type);
	
	my $resized = \0;
	
	my ($width,$height) = $self->Store->image_size($checksum);
	my ($orig_width,$orig_height) = ($width,$height);
	if (defined $maxwidth and $width > $maxwidth) {
		my $ratio = $maxwidth/$width;
		my $newheight = int($ratio * $height);
		
		my $image = Image::Resize->new($self->Store->checksum_to_path($checksum));
		my $gd = $image->resize($maxwidth,$newheight);
		
		my $method = 'png';
		$method = $subtype if ($gd->can($subtype));
		
		my $tmpfile = '/tmp/' . String::Random->new->randregex('[a-z0-9A-Z]{15}');
		open(FH, '> ' . $tmpfile);
		print FH $gd->$method;
		close(FH);
		
		my $newchecksum = $self->Store->add_content_file_mv($tmpfile);
		
		($checksum,$width,$height) = ($newchecksum,$maxwidth,$newheight);
		$resized = \1;
	}
	
	my $tag = '<img src="/simplecas/fetch_content/' . $checksum . '"';
	$tag .= ' width=' . $width . ' height=' . $height if ($width and $height);
	$tag .= '>';
	
	my $packet = {
		success => \1,
		checksum => $checksum,
		height => $height,
		width => $width,
		resized => $resized,
		orig_width => $orig_width,
		orig_height => $orig_height
	};
	
	return $c->res->body(JSON::PP::encode_json($packet));
}


sub upload_file : Local {
	my ($self, $c) = @_;
	
	my $upload = $c->req->upload('Filedata') or die "no upload object";
	my $checksum = $self->Store->add_content_file_mv($upload->tempname) or die "Failed to add content";
	
	my $Content = $self->Content($checksum);
	
	my $packet = {
		success	=> \1,
		filename => $upload->filename,
		checksum	=> $Content->checksum,
		mimetype	=> $Content->mimetype
	};
	
	return $c->res->body(JSON::PP::encode_json($packet));
}



sub upload_echo_base64: Local  {
	my ($self, $c) = @_;

	my $upload = $c->req->upload('Filedata') or die "no upload object";
	
	my $base64 = encode_base64($upload->slurp,'');
	
	my $packet = {
		success => \1,
		echo_content => $base64
	};
	
	return $c->res->body(JSON::PP::encode_json($packet));
}

1;
