package RapidApp;
use strict;
use warnings;

our $VERSION = 0.99005;

# ABSTRACT: Turnkey ajaxy webapps

# use to require some modules:
use SQL::Translator 0.11016;
use DateTime::Format::SQLite;

use File::ShareDir qw(dist_dir);

sub share_dir {
  my $class = shift || __PACKAGE__;
  return $ENV{RAPIDAPP_SHARE_DIR} || dist_dir($class);
}


1;


