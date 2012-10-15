package RapidApp::CatalystX::AutoAssets::Controller;
our $VERSION = '0.01';
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use RapidApp::Include qw(sugar perlutil);

use Switch qw(switch);
use IO::File;
use IO::All;
use Digest::SHA1;

# does nothing yet:
has 'minify', is => 'ro', isa => 'Bool', default => 0;

has 'built_dir', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my $c = $self->_app;
	return $c->config->{home} . '/built_assets';
};

# List of shell globs to include:
has 'inc', is => 'ro', lazy => 1, isa => 'Str', default => sub {
	my $self = shift;
	my $c = $self->_app;
	
	my $home = $c->config->{home};
	$home =~ s/\s+/\\ /g; #<-- escape any whitespace in path
	
	return join(' ',
		$home . '/rapidapp/src.d/*.js',
		$home . '/rapidapp/src.d/*.css',
		$home . '/root/src.d/*.js',
		$home . '/root/src.d*.css',
	);
};

sub BUILD {
	my $self = shift;
	$self->init_built_dir;
	$self->clean_built_dir_tmp_files;
	$self->failsafe_init_check_built_dir;
}

# In case the wrong built_dir was accidently specified, abort (because all files will be deleted)
sub failsafe_init_check_built_dir {
	my $self = shift;
	die "Unexpected existing files detected in built_dir, aborting for safety. " .
	 "Please manually remove the files in '" . $self->built_dir . "' or specify a different directory"
		if(scalar $self->get_built_dir_files > 2);
};



# safe for glob() if built_dir contains whitespace
has 'safe_built_dir', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my $dir = $self->built_dir;
	$dir =~ s/\s+/\\ /g; #<-- escape any whitespace in path
	return $dir;
};

sub init_built_dir {
	my $self = shift;
	return if (-d $self->built_dir);
	mkdir $self->built_dir or die "Failed to create directory: " . $self->built_dir;
}

# List of files currently in the built dir
sub get_built_dir_files {
	my $self = shift;
	return (glob($self->safe_built_dir . '/*'));
}

# Conservative clean up of leftover temp files in built_dir:
# Delete all files that start with dash '-' and end with .js.tmp or .css.tmp
sub clean_built_dir_tmp_files {
	my $self = shift;
	unlink $_ for( grep { $_ =~ /^\-/ } glob(
		$self->safe_built_dir . '/*.js.tmp ' .
		$self->safe_built_dir . '/*.css.tmp'
	));
}



sub get_inc_files {
	my $self = shift;
	return (glob($self->inc));
}

has 'prepared_inc_mtime_concat', is => 'rw', isa => 'Maybe[Str]', default => undef;
sub get_inc_mtime_concat {
	my $self = shift;
	my $list = shift || [ $self->get_inc_files ];
	return join('-', map { xstat($_)->{mtime} } @$list );
}

sub prepare_assets {
	my $self = shift;
	
	my @files = $self->get_inc_files;
	my $mtime_concat = $self->get_inc_mtime_concat(\@files);
	
	# No new changes, return
	return if ($self->prepared_inc_mtime_concat eq $mtime_concat);
	
	# separate css from js files and ignore all other files:
	my @js = ();
	my @css = ();
	($_ =~ /\.js$/ and push @js, $_) or ($_ =~ /\.css$/ and push @css, $_)
		for (@files);
	
	my @assets = (
		$self->generate_asset('js',\@js),
		$self->generate_asset('css',\@css)
	);
	
	# Remove all other files in the built_dir:
	my @unlinks = grep {
		! ($_ ~~ @assets) and	# exclude the asset files we just generated
		! (-d $_) and			# exclude directories (should never happen)
		! ($_ =~ /\.tmp$/)		# exclude tmp files to avoid clobbering files being written by other procs
	} $self->get_built_dir_files;
	unlink $_ for(@unlinks);
	
	# Update mtime_concat
	# TODO: store this in a FastMmap so each process doesn't regenerate the files
	$self->prepared_inc_mtime_concat($mtime_concat);
}


sub generate_asset {
	my $self = shift;
	my $ext = shift or die "No file ext supplied!!!";
	my $files = shift || [];
	
	die '$ext may only be js or css!!' unless ($ext eq 'js' || $ext eq 'css');
	
	$self->init_built_dir;
	my $tmpf = $self->built_dir . '/-' . $$ . '-' . rand . '.' . $ext . '.tmp';
	
	my $fd = IO::File->new($tmpf, '>:raw') or die $!;
	$fd->write($_) for ( map { io($_)->slurp . "\r\n" } @$files );
	$fd->close;
	
	if($self->minify) {
		# TODO ...
		#
	
	}
	
	my $sha1 = $self->file_checksum($tmpf);
	my $asset_name = $sha1 . '.' . $ext;
	my $asset_path = $self->built_dir . '/' . $asset_name;
	
	unlink $asset_path if ($asset_path);
	
	system('mv', $tmpf, $asset_path) == 0
		or die "AutoAssets: Failed to move file '$tmpf' -> '$asset_path'";
	
	$self->_app->log->info(
		'AutoAssets: gen ' . GREEN.BOLD . $asset_path . CLEAR
	);
	
	return $asset_path;
}


sub file_checksum {
	my $self = shift;
	my $file = shift;
	
	my $FH = IO::File->new();
	$FH->open('< ' . $file) or die "$! : $file\n";
	$FH->binmode;
	
	my $sha1 = Digest::SHA1->new->addfile($FH)->hexdigest;
	$FH->close;
	return $sha1;
}


sub index :Path :Args(1) {
    my ( $self, $c, $filename ) = @_;
	
	my ($checksum,$ext) = split(/\./,$filename,2);
	my $fh = $self->get_asset_fh($filename) or return $self->unknown_asset($c);
	
	# Set the Content-Type according to the extention - only 'js' or 'css' current supported:
	switch($ext) {
		case 'js'	{ $c->response->header( 'Content-Type' => 'text/javascript' ); }
		case 'css' 	{ $c->response->header( 'Content-Type' => 'text/css' ); }
		else 		{ return $self->unknown_asset($c); }
	}
	
	# Let browsers cache forever because we're a CAS path! content will always be current:
	$c->response->header( 
		'Cache-Control' => 'public, max-age=31536000, s-max-age=31536000' # 31536000 = 1 year
	); 
	
    return $c->response->body( $fh );
}


sub get_asset_fh {
	my ($self,$filename) = @_;
	
	$self->prepare_assets;
	
	my $file = $self->built_dir . '/' . $filename;
	return undef unless (-f $file);
	
	my $fh = IO::File->new();
	$fh->open('< ' . $file) or die "Failed to open $file for reading.";
	
	return $fh;
}

sub unknown_asset {
	my ($self,$c) = @_;
	$c->res->status(404);
	return $c->res->body('Unknown asset');
}

1;
