package RapidApp::Module::Grid::SearchBox::Exact;

use strict;
use warnings;

use Moo;
extends 'RapidApp::Module::Grid::SearchBox::Normal';
use Types::Standard ':all';

use RapidApp::Util qw(:all);

has '+documentation', default => sub { join(" ",
  'The Exact search is like the Normal search except it only considers whole values and not substrings.',
  "\n\n",
  'Since only whole/exact column values are considered, this is much faster, but is not useful unless you',
  'know exactly what you are looking for, such as a uniue ID value, an SKU, a username, and so on.'
)};


has '+mode_name',       default => sub { 'exact' };
has '+label',           default => sub { 'Exact Search' };
has '+menu_text',       default => sub { 'Exact (faster)' };
has '+exact_matches',   default => sub { 1 };


1;