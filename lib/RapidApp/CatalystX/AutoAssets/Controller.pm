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

require JavaScript::Minifier;
require CSS::Minifier;

has 'minify', is => 'ro', isa => 'Bool', default => 1;

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
		$home . '/root/src.d/*.css',
	);
};

has 'js_asset_path', is => 'rw', isa => 'Maybe[Str]', default => undef;
has 'css_asset_path', is => 'rw', isa => 'Maybe[Str]', default => undef;

sub BUILD {
	my $self = shift;
	$self->init_built_dir;
	$self->clean_built_dir;
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

# Conservative clean up of built_dir. Only delete files that 
# were (probably) created by us:
sub clean_built_dir {
	my $self = shift;
	unlink $_ for( glob(
		$self->safe_built_dir . '/*.js ' .
		$self->safe_built_dir . '/*.css ' .
		$self->safe_built_dir . '/*.js.tmp ' .
		$self->safe_built_dir . '/*.css.tmp'
	));
	
	# this should only be called during BUILD, but should it be called
	# later on for some reason, make sure the assets will be generated
	# on the next request:
	$self->prepared_inc_mtime_concat(undef);
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
	
	$self->js_asset_path( $self->generate_asset('js',\@js) );
	$self->css_asset_path( $self->generate_asset('css',\@css) );
	
	# Clean other files from the built_dir:
	my @unlinks = grep {
		$_ ne $self->js_asset_path and
		$_ ne $self->css_asset_path and
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
	if($self->minify) {
		foreach my $file (@$files) {
			open(INFILE, $file) or die $!;
			my %opt = ( input => *INFILE, outfile => $fd );
			$ext eq 'js' ? JavaScript::Minifier::minify(%opt) : CSS::Minifier::minify(%opt);
			close INFILE;
		}
	}
	else {
		$fd->write($_) for ( map { io($_)->slurp . "\r\n" } @$files );
	}
	$fd->close;
	
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


sub index :Path :Args(2) {
    my ( $self, $c, $checksum, $name ) = @_;
	
	scream($self->html_head_includes);
	
	# Ignore the the client-supplied filename except the file extention
	my ($junk,$ext) = split(/\./,$name,2);
	my $filename = $checksum . '.' . $ext;
	my $fh = $self->get_asset_fh($filename) or return $self->unknown_asset($c);
	
	# Set the Content-Type according to the extention - only 'js' or 'css' current supported:
	switch($ext) {
		case 'js'	{ $c->response->header( 'Content-Type' => 'text/javascript' ); }
		case 'css' 	{ $c->response->header( 'Content-Type' => 'text/css' ); }
		else 		{ return $self->unknown_asset($c); }
	}
	
	# Let browsers cache forever because we're a CAS path! content will always be current
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

sub extract_checksum_ext {
	my $self = shift;
	my $path = shift or die 'expected $path argument not supplied';
	$path =~ /\/([0-9a-f]{40}\.\w+)$/;
	return undef unless ($1);
	return (split(/\./,$1,2));
}

sub asset_path_to_url {
	my $self = shift;
	my $asset_path = shift or die 'expected $asset_path argument not supplied';
	die "asset file '$asset_path' not found!" unless (-f $asset_path);
	
	my ($checksum,$ext) = $self->extract_checksum_ext($asset_path);
	die '$ext may only be js or css!!' unless ($ext eq 'js' || $ext eq 'css');
	
	my $vprefix = $self->minify ? 'rapidapp-minified' : 'rapidapp';
	return '/' . $self->path_prefix($self->_app) . "/$checksum/$vprefix.$ext";
}

sub html_head_includes {
	my $self = shift;
	
	$self->prepare_assets;
	
	my @tags = ();
	push @tags, '<link rel="stylesheet" type="text/css" href="' . 
		$self->asset_path_to_url( $self->css_asset_path ). 
	'" />' if($self->css_asset_path);
	
	push @tags, '<script type="text/javascript" src="' . 
		$self->asset_path_to_url( $self->js_asset_path ). 
	'"></script>' if($self->js_asset_path);
	
	return 
		"\r\n\r\n<!--   AUTO GENERATED BY " . ref($self) . " (AutoAssets)   -->\r\n" .
		( scalar @tags > 0 ? 
			join("\r\n",@tags) : '<!--      NO ASSETS AVAILABLE      -->'
		) .
		"\r\n<!--  ---- END AUTO GENERATED ASSETS ----  -->\r\n\r\n";
}

1;
