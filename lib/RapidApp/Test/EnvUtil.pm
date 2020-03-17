package # hide from PAUSE
     RapidApp::Test::EnvUtil;

# THIS PACKAGE IS ONLY MEANT TO BE USED IN TEST SCRIPTS

use strict;
use warnings;
use Path::Class qw(dir);
use FindBin '$Bin';


# Dynamically set a local TMPDIR to be relative to our
# expected directory structure within the RapidApp t/
# directory. We want to always end up with 't/var/tmp'
sub set_tmpdir_env {

  my $dir = dir($Bin);
  while(-d $dir->parent) {
    if (-d $dir->subdir('testapps')) {
      # we're done
      last;
    }
    elsif(-d $dir->subdir('var') && -d $dir->subdir('var')->subdir('testapps')) {
      # This code path happens when we're called from a .t script
      $dir = $dir->subdir('var');
      last;
    }
    else {
      # keep walking up parent directories (this code path happens when we're
      # being called from a script within the test app)
      $dir = $dir->parent;
    }
  }

  die "Unable to resolve test tmp dir" unless (-d $dir->subdir('testapps'));

  my $tmpdir = $dir->subdir('tmp')->absolute;
  $tmpdir->mkpath unless (-d $tmpdir);

  # Make sure it actually exists/was created:
  die "Error resolving/creating test tmp dir '$tmpdir'" unless (-d $tmpdir);

  # Now, set the TMPDIR env variable (used by Catalyst::Utils::class2tempdir)
  $ENV{TMPDIR} = $tmpdir->stringify;

}


1;
