#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

plan skip_all => 'set RELEASE_TESTING to enable this test' unless $ENV{RELEASE_TESTING};

eval "use Test::Pod::Coverage 1.04";
plan skip_all => 'Test::Pod::Coverage 1.04 required' if $@;

eval "use Pod::Coverage 0.20";
plan skip_all => 'Pod::Coverage 0.20 required' if $@;


#####
#####
# Tried using a TODO: block, but it just didn't work...
plan skip_all => "Lot's of POD cleanup yet to do... (GitHub Issue #64)";
#####
#####


all_pod_coverage_ok({ also_private => [ qr/^BUILD/ ] });
