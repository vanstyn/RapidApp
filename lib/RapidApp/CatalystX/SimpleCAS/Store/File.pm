package RapidApp::CatalystX::SimpleCAS::Store::File;

use warnings;
use Moose;

use RapidApp::Include qw(sugar perlutil);

use File::MimeInfo::Magic;
use Image::Size;
use Digest::SHA1;
use IO::File;
use Data::Dumper;
use MIME::Base64;

use IO::All;

has 'store_dir' => ( is => 'ro', isa => 'Str', required => 1 );


sub init_store_dir {
	my $self = shift;
	return if (-d $self->store_dir);
	mkdir $self->store_dir or die "Failed to create directory: " . $self->store_dir;
}

sub add_content_base64 {
	my $self = shift;
	my $data = decode_base64(shift) or die "Error decoding base64 data. $@";
	return $self->add_content($data);
}

sub add_content {
	my $self = shift;
	my $data = shift;
	
	$self->init_store_dir;
	
	my $checksum = $self->calculate_checksum($data);
	return $checksum if ($self->content_exists($checksum));
	
	my $save_path = $self->checksum_to_path($checksum,1);
	my $fd= IO::File->new($save_path, '>:raw') or die $!;
	$fd->write($data);
	$fd->close;
	return $checksum;
}

sub add_content_file {
	my $self = shift;
	my $file = shift;
	
	$self->init_store_dir;
	
	my $checksum = $self->file_checksum($file);
	return $checksum if ($self->content_exists($checksum));
	
	my $save_path = $self->checksum_to_path($checksum,1);
	
	link $file, $save_path or die "Failed to create link";
	
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
	
	system('mv', $file, $save_path) == 0
		or die "Failed to move file";
	
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
	my $checksum = shift;
	
	my $file = $self->checksum_to_path($checksum);
	return undef unless ( -f $file);
	
	return io($file)->slurp;
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
	
	# See if this is an actual MIME file with a defined Content-Type:
	my $MIME = try{
		my $fh = $self->fetch_content_fh($checksum);
		# only read the begining of the file, enough to make it past the Content-Type header:
		my $buf; $fh->read($buf,1024); $fh->close;
		return Email::MIME->new($buf);
	};
	if($MIME && $MIME->content_type) {
		my ($type) = split(/\s*\;\s*/,$MIME->content_type);
		return $type;
	}
	
	# Otherwise, guess the mimetype from the file on disk
	my $file = $self->checksum_to_path($checksum);
	
	return undef unless ( -f $file );
	return mimetype($file);
}

sub calculate_checksum {
	my $self = shift;
	my $data = shift;
	
	my $sha1 = Digest::SHA1->new->add($data)->hexdigest;
	return $sha1;
}

sub file_checksum  {
	my $self = shift;
	my $file = shift;
	
	my $FH = IO::File->new();
	$FH->open('< ' . $file) or die "$! : $file\n";
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