package RapidApp::CatalystX::SimpleCAS::Store::Git;

## NOTE: This SimpleCas store/backend was never finished because the 'File'
## store/backend is simple, works, and is all that is really needed. This
## class probably doesn't work or implement the expected store API...


use warnings;
use Moose;

use Git::Repository;
use File::MimeInfo::Magic;
use Data::Dumper;

has 'git_dir' => ( is => 'ro', isa => 'Str', required => 1 );

has 'GitRepo' => (
	is => 'ro',
	lazy => 1,
	isa => 'Git::Repository',
	default => sub {
		my $self = shift;
		
		unless( -d $self->git_dir ) {
			mkdir($self->git_dir) or die "Failed to create " . $self->git_dir;
			chdir $self->git_dir;
			return Git::Repository->create( init => '--bare' );
		}
		
		return Git::Repository->new( git_dir => $self->git_dir );
	}
);


sub add_content_fh {
	my $self = shift;
	my $fh = shift;
	
	my $cmd = $self->GitRepo->command( 'hash-object' => '-w', '--stdin' );
	
	my $buf = '';
	my $len = 4096;
	while($fh->read($buf,$len)) {
		$cmd->stdin->write($buf);
	}
	$cmd->stdin->close;

	my @out = $cmd->stdout->getlines;
	my @err = $cmd->stderr->getlines;
	
	$cmd->close;
	
	if($cmd->exit) {
		die join('',@err);
	}
	
	my $sha1 = shift @out;
	chomp $sha1;
	
	return $sha1;
}


sub fetch_content {
	my $self = shift;
	my $sha1 = shift;
	
	my $fh = $self->fetch_content_fh($sha1) or return undef;
	
	my @out = $fh->getlines;
	return join('',@out);
}

sub fetch_content_fh {
	my $self = shift;
	my $sha1 = shift;
	
	return undef unless ($self->content_exists($sha1));
	
	my $cmd = $self->GitRepo->command( 'cat-file' => 'blob', $sha1 );
	my $fh = $cmd->stdout or return undef;
	return $fh;
}


sub content_exists {
	my $self = shift;
	my $sha1 = shift;
	
	#don't allow sha1s less than 40 characters long:
	return 0 unless (length($sha1) == 40);
	
	my $cmd = $self->GitRepo->command( 'cat-file' => '-t', $sha1 );
	my @out = $cmd->stdout->getlines;
	my @err = $cmd->stderr->getlines;
	$cmd->close;
	
	return 1 unless ($cmd->exit);
	return 0;
}


sub content_mimetype {
	my $self = shift;
	my $sha1 = shift;
	my $tmp = '/tmp/' . $sha1;
	$self->write_content_to_file($sha1,$tmp);
	return mimetype($tmp);
	
	#my $path = $self->content_filepath($sha1) or return undef;
	
}


sub content_filepath {
	my $self = shift;
	my $sha1 = shift;
	my $d = substr($sha1,0,2);
	my $f = substr($sha1,2);
	my $path = $self->git_dir . '/objects/' . $d . '/' . $f;
	
	print STDERR "\n\n" . $path . "\n\n";
	
	return undef unless (-f $path);
	return $path;
}


sub write_content_to_file {
	my $self = shift;
	my $sha1 = shift;
	my $file = shift;
	
	my $fh = $self->fetch_content_fh($sha1);
	my $FileH = IO::File->new();
	$FileH->open('> ' . $file) or die "Filed to open $file for writing.";
	
	my $buf = '';
	my $len = 4096;
	while($fh->read($buf,$len)) {
		$FileH->write($buf);
	}
	$FileH->close;
	
	return 1;
}


#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;