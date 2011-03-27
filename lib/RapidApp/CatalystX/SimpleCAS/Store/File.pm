package RapidApp::CatalystX::SimpleCAS::Store::File;

use warnings;
use Moose;

use File::MimeInfo::Magic;
use Digest::MD5::File qw(file_md5_hex);
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
	
	return file_md5_hex($file);
}


#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;