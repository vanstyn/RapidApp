package RapidApp::CatalystX::AutoAssets::Controller;
our $VERSION = '0.01';
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }


=head1 NAME

RapidApp::CatalystX::AutoAssets::Controller - Catalyst Controller

=head1 DESCRIPTION

Controller for CAS/checksum serving of JavaScript and CSS.

See RapidApp::CatalystX::AutoAssets Plugin

=cut


use RapidApp::Include qw(sugar perlutil);

use Switch qw(switch);
use IO::File;
use IO::All;
use Digest::SHA1;
use File::Path qw(make_path remove_tree);
use Fcntl qw( :DEFAULT :flock :seek F_GETFL );

require JavaScript::Minifier;
require CSS::Minifier;

has 'minify', is => 'ro', isa => 'Bool', default => 0;

has 'work_dir', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my $c = $self->_app;
	return $c->config->{home} . '/root/autoassets';
};

has 'built_dir', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return $self->work_dir . '/_built';
};

has 'built_fingerprint_file', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return $self->work_dir . '/.built_fingerprint';
};

has 'build_lock_file', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return $self->work_dir . '/.lockfile';
};

has 'extjs_theme_css', is => 'ro', lazy => 1, isa => 'Str', default => sub {
	my $self = shift;
	my $c = $self->_app;
	my $home = $c->config->{home};
	return $home . '/root/static/ext/resources/css/xtheme-gray.css'
};

# List of shell globs to include:
has 'inc', is => 'ro', lazy => 1, isa => 'Str', default => sub {
	my $self = shift;
	my $c = $self->_app;
	
	my $home = $c->config->{home};
	$home =~ s/\s+/\\ /g; #<-- escape any whitespace in path
	
	my @globs = (
		## -- not serving ext css via AutoAsset yet because of relative paths in css
		##$home . '/root/static/ext/resources/css/ext-all.css',
		##$self->extjs_theme_css,
		##$home . '/root/static/ext/examples/ux/fileuploadfield/css/fileuploadfield.css',
		## --
		$home . '/root/static/ext/adapter/ext/ext-base.js', 
		#$home . '/root/static/ext/ext-all.js', #<-- TODO: option alternate debug version
		$home . '/root/static/ext/ext-all-debug.js', #<-- TODO: option alternate debug version
		$home . '/root/static/ext/src/debug.js', #<-- TODO: option alternate debug version
		$home . '/root/static/ext/examples/ux/fileuploadfield/FileUploadField.js'
	);
	
	my @files = qw(*.js *.css js/*.js css/*.css);
	my @dirs = ($home . '/rapidapp/src.d/', $home . '/root/src.d/');
	
	foreach my $dir (@dirs) {
		push @globs, $dir . $_ for (@files);
	}
	
	return join(' ',@globs);
};

has 'js_asset_path', is => 'rw', isa => 'Maybe[Str]', default => undef;
has 'css_asset_path', is => 'rw', isa => 'Maybe[Str]', default => undef;

sub BUILD {
	my $self = shift;
	$self->init_work_dir;
}


## safe for glob() if built_dir contains whitespace
has 'safe_built_dir', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my $dir = $self->built_dir;
	$dir =~ s/\s+/\\ /g; #<-- escape any whitespace in path
	return $dir;
};


sub init_work_dir {
	my $self = shift;
	return if (-d $self->built_dir);
	my $err;
	make_path($self->built_dir, {error => \$err});
	die join("\n",@$err) if (scalar @$err > 0);
}

# List of files currently in the built dir
sub get_built_dir_files {
	my $self = shift;
	return (glob($self->safe_built_dir . '/*'));
}

# Conservative clean up of built_dir. Only delete files that 
# were (probably) created by us:
#sub clean_built_dir {
#	my $self = shift;
#	unlink $_ for( glob(
#		$self->safe_built_dir . '/*.js ' .
#		$self->safe_built_dir . '/*.css ' .
#		$self->safe_built_dir . '/*.js.tmp ' .
#		$self->safe_built_dir . '/*.css.tmp'
#	));
#	
#	# this should only be called during BUILD, but should it be called
#	# later on for some reason, make sure the assets will be generated
#	# on the next request:
#	$self->inc_mtimes(undef);
#}


sub get_inc_files {
	my $self = shift;
	return (glob($self->inc));
}

has 'max_fingerprint_calc_age', is => 'ro', isa => 'Int', default => (60*60*12); # 12 hours
has 'last_fingerprint_calculated', is => 'rw', isa => 'Maybe[Int]', default => undef;

has 'built_mtime', is => 'rw', isa => 'Maybe[Str]', default => undef;
sub get_built_mtime {
	my $self = shift;
	$self->init_work_dir;
	return xstat($self->built_dir)->{mtime};
}

has 'inc_mtimes', is => 'rw', isa => 'Maybe[Str]', default => undef;
sub get_inc_mtime_concat {
	my $self = shift;
	my $list = shift || [ $self->get_inc_files ];
	return join('-', map { xstat($_)->{mtime} } @$list );
}


sub calculate_fingerprint {
	my $self = shift;
	my @built = $self->get_built_dir_files;
	return undef unless (scalar @built == 2); #<-- there should be exactly 2 built files
	my $sha1 = $self->file_checksum($self->get_inc_files,@built);
	$self->last_fingerprint_calculated(time) if ($sha1);
	return $sha1;
}

sub current_fingerprint {
	my $self = shift;
	return undef unless (-f $self->built_fingerprint_file);
	my $fingerprint = io($self->built_fingerprint_file)->slurp;
	return $fingerprint;
}

sub save_fingerprint {
	my $self = shift;
	my $fingerprint = shift or die "Expected fingerprint/checksum argument";
	return io($self->built_fingerprint_file)->print($fingerprint);
}

sub calculate_save_fingerprint {
	my $self = shift;
	my $fingerprint = $self->calculate_fingerprint or return 0;
	return $self->save_fingerprint($fingerprint);
}

sub fingerprint_calc_current {
	my $self = shift;
	my $last = $self->last_fingerprint_calculated or return 0;
	return 1 if (time - $last < $self->max_fingerprint_calc_age);
	return 0;
}

sub prepare_assets {
	my $self = shift;
	
	my @files = $self->get_inc_files;
	my $inc_mtimes = $self->get_inc_mtime_concat(\@files);
	my $built_mtime = $self->get_built_mtime;
	
	# Check cached mtimes to see if anything has changed. This is a lighter
	# first pass check than the fingerprint check which calculates a sha1 for
	# all the source files and existing built files
	return if (
		$self->fingerprint_calc_current &&
		$self->inc_mtimes eq $inc_mtimes && 
		$self->built_mtime eq $built_mtime
	);
	
	# --- Blocks for up to 2 minutes waiting to get an exclusive lock or dies
	$self->get_build_lock;
	# ---
	
	# Check the fingerprint:
	my $fingerprint = $self->calculate_fingerprint;
	if($fingerprint && $self->current_fingerprint eq $fingerprint) {
		# If the mtimes changed but the fingerprint matches we don't need to regenerate. 
		# This will happen if another process just built the files while we were waiting 
		# for the lock and on the very first time after the application starts up
		$self->inc_mtimes($inc_mtimes);
		$self->built_mtime($built_mtime);
		$self->find_set_unknown_asset_paths; #<-- only applies to first call when assets are already built
		return $self->release_build_lock;
	}
	
	# Need to do a rebuild:
	
	# remove any old built files:
	remove_tree( $self->built_dir, {keep_root => 1} );
	
	# separate css from js files and ignore all other files:
	my @js = ();
	my @css = ();
	($_ =~ /\.js$/ and push @js, $_) or ($_ =~ /\.css$/ and push @css, $_)
		for (@files);
	
	# -- Do the actual building:
	$self->js_asset_path( $self->generate_asset('js',\@js) );
	$self->css_asset_path( $self->generate_asset('css',\@css) );
	# --
	
	# Update the fingerprint (global) and cached mtimes (specific to the current process)
	$self->inc_mtimes($inc_mtimes);
	$self->built_mtime($self->get_built_mtime);
	$self->calculate_save_fingerprint;
	
	# Release the lock and return:
	return $self->release_build_lock;
}


sub generate_asset {
	my $self = shift;
	my $ext = shift or die "No file ext supplied!!!";
	my $files = shift || [];
	
	die '$ext may only be js or css!!' unless ($ext eq 'js' || $ext eq 'css');
	
	$self->init_work_dir;
	my $tmpf = $self->built_dir . '/-' . $ext . '.tmp';
	
	my $fd = IO::File->new($tmpf, '>:raw') or die $!;
	if($self->minify) {
		foreach my $file (@$files) {
			open(INFILE, $file) or die $!;
			my %opt = ( input => *INFILE, outfile => $fd );
			$ext eq 'js' ? JavaScript::Minifier::minify(%opt) : CSS::Minifier::minify(%opt);
			close INFILE;
			$fd->write("\r\n");
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
	my @files = @_;
	
	my $Sha1 = Digest::SHA1->new;
	foreach my $file (@files) {
		my $FH = IO::File->new();
		$FH->open('< ' . $file) or die "$! : $file\n";
		$FH->binmode;
		$Sha1->addfile($FH);
		$FH->close;
	}
	
	return $Sha1->hexdigest;
}


sub index :Path :Args(2) {
    my ( $self, $c, $checksum, $name ) = @_;
	
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

#### ---
#### TODO: FIX ME - temp remap/redirect to ext - needed because of relative paths in ext css
##sub images :Local {
##	my ( $self, $c, @args ) = @_;
##	my $path = '/static/ext/resources/images/' . join('/',@args);
##	$c->response->header( 
##		'Cache-Control' => 'public, max-age=86400, s-max-age=86400' # 86400 = 1 day
##	); 
##	$c->response->body(' ');
##	return $c->response->redirect($path);
##}
#### ---

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

# Needed if current assets are already built but we don't know what they are:
sub find_set_unknown_asset_paths {
	my $self = shift;
	return if ($self->css_asset_path && $self->js_asset_path);
	my @built = $self->get_built_dir_files;
	foreach my $path (@built) {
		$self->css_asset_path( $path ) if ($path =~ /\.css$/);
		$self->js_asset_path( $path ) if ($path =~ /\.js$/);
	}
}


has 'max_lock_wait', is => 'ro', isa => 'Int', default => 120;

sub get_build_lock_wait {
	my $self = shift;
	my $start = time;
	until($self->get_build_lock) {
		my $elapsed = time - $start;
		die "AutoAssets: aborting waiting for lock after $elapsed"
			if ($elapsed >= $self->max_lock_wait);
		sleep 1;
	}
}

sub get_build_lock {
	my $self = shift;
	my $fname = $self->build_lock_file;
	sysopen(LOCKHANDLE, $fname, O_RDWR|O_CREAT|O_EXCL, 0644)
		or sysopen(LOCKHANDLE, $fname, O_RDWR)
		or die "Unable to create or open $fname\n";
	fcntl(LOCKHANDLE, F_SETFD, FD_CLOEXEC) or die "Failed to set close-on-exec for $fname";
	my $lockStruct= pack('sslll', F_WRLCK, SEEK_SET, 0, 0, $$);
	if (fcntl(LOCKHANDLE, F_SETLK, $lockStruct)) {
		my $data= "$$";
		syswrite(LOCKHANDLE, $data, length($data)) or die "Failed to write pid to $fname";
		truncate(LOCKHANDLE, length($data)) or die "Failed to resize $fname";
		# we do not close the file, so that we maintain the lock.
		return 1;
	}
	$self->release_build_lock;
	return 0;
}

sub release_build_lock {
	my $self = shift;
	close LOCKHANDLE;
}

sub end :Private {
	my ($self,$c) = @_;
	# Make sure we never keep a build lock past the end of a request:
	$self->release_build_lock;
}




1;
