#!/usr/bin/env perl

# -----------------------------------------------------------------------------
# This script dumps bash 'export' commands needed to update shell environment
# variables. It is the internal guts for source_dev_shell_vars.bash and is
# not intended to be called directly. The only reason this script exists is
# because I was too lazy to write it in bash, even though the only way that
# shell env vars can be updated is via 'sourcing' a bash script, which is what
# the parent script source_dev_shell_vars.bash is for.
#
# #166 (https://github.com/vanstyn/RapidApp/issues/166)
# -----------------------------------------------------------------------------

use strict;
use warnings;
use List::Util;

use Path::Class qw/file dir/;
my $repo_dir = file($0)->parent->parent->absolute;

die "Doesn't look like I'm within a RapidApp repo" unless (
  -f $repo_dir->subdir('script')->file('rdbic.pl')
);

my $exports = {
  PERLLIB => &_prepend_colon_list( $ENV{PERLLIB}, $repo_dir->subdir('lib')->stringify ),
  PATH    => &_prepend_colon_list( $ENV{PATH},    $repo_dir->subdir('script')->stringify ),
  RAPIDAPP_SHARE_DIR => $repo_dir->subdir('share')
};

# Just print the export commands on STDOUT and exit:
print join("\n", map { "export $_=$exports->{$_}" } keys %$exports);

exit 0;


##############################################

sub _prepend_colon_list {
  my ($clist, $add) = @_;

  my @list = split(/:/,($clist||''));

  return ( List::Util::first { $_ eq $add } @list )
    ? $clist
    : join(':',$add,@list)
}

