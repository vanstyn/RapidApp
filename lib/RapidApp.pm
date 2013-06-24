package RapidApp;
use strict;
use warnings;

our $VERSION = 0.99004;

# ABSTRACT: Turnkey ajaxy webapps

use File::ShareDir qw(dist_dir);

sub share_dir {
  my $class = shift || __PACKAGE__;
  return $ENV{RAPIDAPP_SHARE_DIR} || dist_dir($class);
}


1;


