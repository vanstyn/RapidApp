#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN {
    unless ($ENV{AUTHOR_TESTING})
    {
        use Test::More;
        plan skip_all => 'set AUTHOR_TESTING to enable this test' unless $ENV{AUTHOR_TESTING};
    }
}

# Note: we're doing all this funky/ugly eval wrap stuff because of the way
# Test::Kwalitee is written to launch tests via import args. We cannot call
# 'use Test::Kwalitee' at any point *AND* do a pkg version check because of
# perl load/compile order. If I find a free moment, I'm tempted to create
# 'Test::Kwalitee::Runtime' which would handle this and export a normal,
# runtime test sub, like 'test_kwalitee()'


my $min_ver = 1.19;
eval { require Test::Kwalitee; };
plan skip_all => "Test::Kwalitee $min_ver required"
  if $@ || $min_ver > $Test::Kwalitee::VERSION;


my @test_args = qw(
  -metayml_conforms_to_known_spec
  -metayml_conforms_to_known_spec
  -metayml_is_parsable
  -has_buildtool
  -has_manifest
  -has_meta_yml
);

# Need to find a way to exclude .build/ (is already excluded in .gitignore)
push @test_args, '-no_symlinks';


# We also have to manually call ->import() like this to be able to programatically
# set and use/access the array which we're building at *runtime* above (since 'use' is
# evaluated at compile time). I really don't understand the rationale behind
# why Test::Kwalitee is designed like this...

Test::Kwalitee->import( tests => [@test_args] );
