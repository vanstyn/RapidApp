package RapidApp::Module::Grid::SearchBox::Exact;

use strict;
use warnings;

use Moo;
extends 'RapidApp::Module::Grid::SearchBox::Normal';
use Types::Standard ':all';

use RapidApp::Util qw(:all);


has '+mode_name',       default => sub { 'exact' };
has '+label',           default => sub { 'Exact Search' };
has '+exact_matches',   default => sub { 1 };


1;