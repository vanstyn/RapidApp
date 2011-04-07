#!/usr/bin/env perl

=head1 NAME

rapidapp_cas_copy

=head1 DESCRIPTION

This script copies a list of CAS (content-addressed-storage) entries from one Db to another.

=head1 SYNOPSIS

  $ script/rapidapp_cas_copy.pl --source SOURCE_CAS_PATH --dest DEST_CAS_PATH [--listfile FILE] [CKSUM, ...]

=head1 OPTIONS

=over

=item B<--help> (-?)

This help text

=item B<--source> (-s) SOURCE_CAS_PATH  (required)

Copy from the Content-Addressed-Storage tree at SOURCE_CAS_PATH

=item B<--dest> (-d) DEST_CAS_PATH  (required)

Copy into the Content-Addressed-Storage tree at DEST_CAS_PATH

=item B<--listfile> (-f) FILE

Use the list from the file, in addition to any hashes specified on the command line.

The file must be a simple list of hashes, one per line.
Comments are allowed via lines beginning with "#".

=back

=cut

BEGIN {
	# be friendly and set the lib path automatically
	if (!eval "use RapidApp::CatalystX::SimpleCAS::Store::File;") {
		require lib;
		my $pkg= 'RapidApp/CatalystX/SimpleCAS/Store/File.pm';
		for my $libpath (qw( ./lib ./rapidapp/lib ./RapidApp/lib ../lib ../rapidapp/lib ../RapidApp/lib)) {
			if (-f $libpath.'/'.$pkg) {
				warn "Warning: Taking a guess that the rapidapp lib path is $libpath\n";
				lib->import($libpath);
				require $pkg;
				last;
			}
		}
	}
}

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use IO::Handle;
use IO::File;
use Try::Tiny;

my $help  = 0;
my $src;
my $dst;
my $listfile;
my $verbose;

GetOptions(
	'help|?'        => \$help,
	'source|s=s'    => \$src,
	'dest|d=s'      => \$dst,
	'listfile|f=s'  => \$listfile,
	'verbose|v'     => \$verbose,
) or pod2usage(1);

pod2usage(0) if $help;

defined $src or pod2usage("Must specify --source (-s)");
defined $dst or pod2usage("Must specify --dest (-d)");

-d $src or die "Source does not exist: $src\n";
-d $dst or die "Dest does not exist: $dst\n";

$src= RapidApp::CatalystX::SimpleCAS::Store::File->new(store_dir => $src);
$dst= RapidApp::CatalystX::SimpleCAS::Store::File->new(store_dir => $dst);

my @names= @ARGV;

if (defined $listfile) {
	my $fd= IO::File->new($listfile, "r") or return "$listfile: $!";
	# strip out spaces and ignore comment and empty lines for all lines in listfile
	while (my $line= $fd->getline()) {
		$line =~ s/\s//g;
		next if $line =~ /^\s#/;
		next unless length $line;
		push @names, $line;
	}
}

print STDERR "Checking ".scalar(@names)." checksums\n";

# now copy all of them
# (sort so that we deal with one CAS directory at a time.  should be faster)
my $copied= 0;
copy_entry($_) for (sort @names);

sub copy_entry {
	my $cksum= shift;
	
	length($cksum) > 2 or die "Invalid entry name: $cksum\n";
	
	if ($dst->content_exists($cksum)) {
		print STDERR "exists: $cksum\n" if $verbose;
		return;
	}
	
	$src->content_exists($cksum)
		or die "Entry $cksum does not exist in source CAS!\n";
	
	my $file= $src->checksum_to_path($cksum);
	$dst->file_checksum($file) eq $cksum
		or die "Checksum for $file does not match its content!\n";
	
	my $hash= $dst->add_content_file($file);
	$hash eq $cksum or die "Checksum returned by dest->add did not match, for unknown reasons!\n";
	
	++$copied;
	print STDERR "copied: $cksum\n" if $verbose;
}

print STDERR "Copied $copied entries\n";
print STDERR "Done.\n";