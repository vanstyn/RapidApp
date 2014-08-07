#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

plan skip_all => 'set RELEASE_TESTING to enable this test' unless $ENV{RELEASE_TESTING};

eval "use Test::Spelling 0.19";
plan skip_all => 'Test::Spelling 0.19 required' if $@;

add_stopwords(qw(
    SimpleCAS CAS DBIC sha MHTML Addl checksum fh filelink imglink
    mimetype deduplicates resize resized Cas refactored Filedata
    RapidApp IntelliTree Styn llc 
));

set_spell_cmd('aspell list -l en');
all_pod_files_spelling_ok();

done_testing();
