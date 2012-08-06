package RapidApp::CatalystX::SimpleCAS::Controller;
our $VERSION = '0.01';
use Moose;
use namespace::autoclean;

use RapidApp::Include qw(sugar perlutil);

BEGIN { extends 'Catalyst::Controller' }

use RapidApp::CatalystX::SimpleCAS::Content;
use RapidApp::CatalystX::SimpleCAS::Store::File;
use JSON::PP;
use MIME::Base64;
use Image::Resize;
use String::Random;

has 'store_class', is => 'ro', default => 'RapidApp::CatalystX::SimpleCAS::Store::File';
has 'store_path', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my $c = $self->_app;
	# Default Cas Store path if none was supplied in the config:
	return $c->config->{home} . '/cas_store';
};

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
	
	if ($filename) {
		$filename =~ s/\"/\'/g;
		$disposition = 'attachment; filename="' . $filename . '"';	
	}
	
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
	my ($self, $c, $maxwidth, $maxheight) = @_;

	my $upload = $c->req->upload('Filedata') or die "no upload object";
	
	my ($type,$subtype) = split(/\//,$upload->type);
	
	my ($checksum,$width,$height,$resized,$orig_width,$orig_height) 
		= $self->add_resize_image($upload->tempname,$type,$subtype,$maxwidth,$maxheight);
	
	unlink $upload->tempname;
	
	#my $tag = '<img src="/simplecas/fetch_content/' . $checksum . '"';
	#$tag .= ' width=' . $width . ' height=' . $height if ($width and $height);
	#$tag .= '>';
	
	my $packet = {
		success => \1,
		checksum => $checksum,
		height => $height,
		width => $width,
		resized => $resized,
		orig_width => $orig_width,
		orig_height => $orig_height,
		filename => $self->safe_filename($upload->filename),
	};
	
	return $c->res->body(JSON::PP::encode_json($packet));
}



sub add_resize_image :Private {
	my ($self,$file,$type,$subtype,$maxwidth,$maxheight) = @_;

	my $checksum = $self->Store->add_content_file($file) or die "Failed to add content";
	
	my $resized = \0;
	
	my ($width,$height) = $self->Store->image_size($checksum);
	my ($orig_width,$orig_height) = ($width,$height);
	if (defined $maxwidth) {
		
		my ($newwidth,$newheight) = ($width,$height);
		
		if($width > $maxwidth) {
			my $ratio = $maxwidth/$width;
			$newheight = int($ratio * $height);
			$newwidth = $maxwidth;
		}
		
		if(defined $maxheight and $newheight > $maxheight) {
			my $ratio = $maxheight/$newheight;
			$newwidth = int($ratio * $newwidth);
			$newheight = $maxheight;
		}
		
		unless ($newwidth == $width && $newheight == $height) {
		
			my $image = Image::Resize->new($self->Store->checksum_to_path($checksum));
			my $gd = $image->resize($newwidth,$newheight);
			
			my $method = 'png';
			$method = $subtype if ($gd->can($subtype));
			
			my $tmpfile = '/tmp/' . String::Random->new->randregex('[a-z0-9A-Z]{15}');
			open(FH, '> ' . $tmpfile);
			print FH $gd->$method;
			close(FH);
			
			my $newchecksum = $self->Store->add_content_file_mv($tmpfile);
			
			($checksum,$width,$height) = ($newchecksum,$newwidth,$newheight);
			$resized = \1;
		}
	}
	
	return ($checksum,$width,$height,$resized,$orig_width,$orig_height);
}



sub upload_file : Local {
	my ($self, $c) = @_;
	
	my $upload = $c->req->upload('Filedata') or die "no upload object";
	my $checksum = $self->Store->add_content_file_mv($upload->tempname) or die "Failed to add content";
	
	my @css_class = ('filelink');
	
	my @parts = split(/\./,$upload->filename);
	my $file_ext = lc(pop @parts);
	
	push @css_class, $file_ext if (scalar @parts > 0);
	
	my $Content = $self->Content($checksum);
	
	my $packet = {
		success	=> \1,
		filename => $self->safe_filename($upload->filename),
		checksum	=> $Content->checksum,
		mimetype	=> $Content->mimetype,
		css_class => join(' ',@css_class)
	};
	
	return $c->res->body(JSON::PP::encode_json($packet));
}


sub safe_filename {
	my $self = shift;
	my $filename = shift;
	
	my @parts = split(/[\\\/]/,$filename);
	return pop @parts;
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
