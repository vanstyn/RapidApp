package RapidApp::CatalystX::SimpleCAS::Store::File;

use warnings;
use Moose;

use File::MimeInfo::Magic;
use Image::Size;
use Digest::SHA1;
use IO::File;
use Data::Dumper;

has 'store_dir' => ( is => 'ro', isa => 'Str', required => 1 );


sub init_store_dir {
	my $self = shift;
	return if (-d $self->store_dir);
	mkdir $self->store_dir or die "Failed to create directory: " . $self->store_dir;
}


sub add_content_file {
	my $self = shift;
	my $file = shift;
	
	$self->init_store_dir;
	
	my $checksum = $self->file_checksum($file);
	return $checksum if ($self->content_exists($checksum));
	
	my $save_path = $self->checksum_to_path($checksum,1);
	
	my $cmd = "ln '$file' '$save_path'";
	qx{$cmd};
	die "Failed to create link" if ($?);
	
	return $checksum;
}


sub add_content_file_mv {
	my $self = shift;
	my $file = shift;
	
	$self->init_store_dir;
	
	my $checksum = $self->file_checksum($file);
	if ($self->content_exists($checksum)) {
		unlink $file;
		return $checksum
	}
	
	my $save_path = $self->checksum_to_path($checksum,1);
	
	my $cmd = "mv '$file' '$save_path'";
	qx{$cmd};
	die "Failed to move file" if ($?);
	
	return $checksum;
}



sub split_checksum {
	my $self = shift;
	my $checksum = shift;
	
	return ( substr($checksum,0,2), substr($checksum,2) );
}

sub checksum_to_path {
	my $self = shift;
	my $checksum = shift;
	my $init = shift;
	
	$self->init_store_dir;
	
	my ($d, $f) = $self->split_checksum($checksum);
	
	my $dir = $self->store_dir . '/' . $d;
	if($init and not -d $dir) {
		mkdir $dir or die "Failed to create directory: " . $dir;
	}
	
	return $dir . '/' . $f;
}

sub fetch_content {
	my $self = shift;
	my $sha1 = shift;
	
	my $fh = $self->fetch_content_fh($sha1) or return undef;
	
	my @out = $fh->getlines;
	return join('',@out);
}

sub content_exists {
	my $self = shift;
	my $checksum = shift;
	
	return 1 if ( -f $self->checksum_to_path($checksum) );
	return 0;
}

sub fetch_content_fh {
	my $self = shift;
	my $checksum = shift;
	
	my $file = $self->checksum_to_path($checksum);
	return undef unless ( -f $file);
	
	my $fh = IO::File->new();
	$fh->open('< ' . $file) or die "Failed to open $file for reading.";
	
	return $fh;
}


sub content_mimetype {
	my $self = shift;
	my $checksum = shift;
	
	my $file = $self->checksum_to_path($checksum);
	
	return undef unless ( -f $file );
	return mimetype($file);
}


sub file_checksum  {
	my $self = shift;
	my $file = shift;
	
	my $FH = IO::File->new();
	$FH->open('< ' . $file);
	$FH->binmode;
	
	my $sha1 = Digest::SHA1->new->addfile($FH)->hexdigest;
	$FH->close;
	return $sha1;
}

sub image_size {
	my $self = shift;
	my $checksum = shift;
	
	my $content_type = $self->content_mimetype($checksum) or return undef;
	my ($mime_type,$mime_subtype) = split(/\//,$content_type);
	return undef unless ($mime_type eq 'image');
	
	my ($width,$height) = imgsize($self->checksum_to_path($checksum)) or return undef;
	return ($width,$height);
}



sub content_size {
	my $self = shift;
	my $checksum = shift;
	
	my $file = $self->checksum_to_path($checksum);
	
	return $self->xstat($file)->{size};
}


sub xstat {
	my $self = shift;
	my $file = shift;

	return undef unless (-e $file);

	my $h = {};

	($h->{dev},$h->{ino},$h->{mode},$h->{nlink},$h->{uid},$h->{gid},$h->{rdev},
			 $h->{size},$h->{atime},$h->{mtime},$h->{ctime},$h->{blksize},$h->{blocks})
						  = stat($file);

	return $h;
}


#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;