#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN {
    unless ($ENV{RELEASE_TESTING})
    {
        use Test::More;
        plan skip_all => 'set RELEASE_TESTING to enable this test' unless $ENV{RELEASE_TESTING};
    }
}

use Test::Kwalitee;

## To skip items that Dist::Zilla handles for us:
#use Test::Kwalitee tests => [ qw(
#  -metayml_conforms_to_known_spec
#  -metayml_conforms_to_known_spec
#  -metayml_is_parsable
#  -has_buildtool
#  -has_manifest
#  -has_meta_yml
#) ];
