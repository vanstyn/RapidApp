package RapidApp;
use strict;
use warnings;

our $VERSION = 0.99007;

# ABSTRACT: Turnkey ajaxy webapps

# use to require some modules with specific min versions:
use Catalyst 5.90002;
use DBIx::Class 0.08250;
use SQL::Translator 0.11016;
use Template 2.24;
use DateTime::Format::SQLite;
use JavaScript::ExtJS::V3 '3.4.0';

# quick Module version check cmd:
#   perl -M"Catalyst 999" -e1

use File::ShareDir qw(dist_dir);

sub share_dir {
  my $class = shift || __PACKAGE__;
  return $ENV{RAPIDAPP_SHARE_DIR} || dist_dir($class);
}


1;


