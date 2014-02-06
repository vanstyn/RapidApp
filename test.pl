#!/usr/bin/perl

use strict;
use warnings;


my $str =sprintf(
      '( SELECT COALESCE( MAX( shadowed_lifecycle ), 0 ) + 1 FROM %s sub__query %s)',
      'foo'
    ); 

print "\n\n$str\n\n";


