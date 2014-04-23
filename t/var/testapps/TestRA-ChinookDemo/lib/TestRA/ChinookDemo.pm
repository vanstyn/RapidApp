package # hide from PAUSE
     TestRA::ChinookDemo;
use Moose;
use namespace::autoclean;

# ----------
# Dynamically set a local TMPDIR to be relative to our
# expected directory structure within the RapidApp t/
# directory. We want to always end up with 't/var/tmp'
BEGIN {
  use Path::Class qw(dir);
  use FindBin '$Bin';
  
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
# ----------

use Catalyst::Runtime 5.80;

use RapidApp;
use Catalyst qw/RapidApp::RapidDbic/;

extends 'Catalyst';

our $VERSION = '0.01';

# This is the smallest valid RapidDbic app config:
__PACKAGE__->config(
  name => 'TestRA::ChinookDemo',
  'Plugin::RapidApp::RapidDbic' => {
    dbic_models => ['DB']
  }
);

# Start the application
__PACKAGE__->setup();


1;
