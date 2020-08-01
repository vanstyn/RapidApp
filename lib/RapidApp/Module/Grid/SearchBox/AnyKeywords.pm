package RapidApp::Module::Grid::SearchBox::AnyKeywords;

use strict;
use warnings;

use Moo;
extends 'RapidApp::Module::Grid::SearchBox::Normal';
use Types::Standard ':all';

use RapidApp::Util qw(:all);

has '+documentation', default => sub { join(" ",
  'The keyword search considers each word of the typed in query separately, rather then considering the',
  'query as a single value to match'.
  "\n\n",
  'For instance, with this mode, if you searched for "Foo Bar" the result would include all rows with any',
  'of the selected columns containing the value "Foo" or the value "Bar" rather then matching only values',
  'containing "Foo Bar" together and in that order.',
  "\n\n",
  "This is one of the broadest, deep substring search modes, so it can potentially be extremely slow, depending",
  "on which columns are included in the search and the total number of rows in the table, so it should be used",
  "selectively and with caution"
)};


has '+mode_name',       default => sub { 'any_keyword' };
has '+label',           default => sub { 'Search Keywords' };
has '+menu_text',       default => sub { 'Keywords (Any)' };


sub chain_query_search_rs {
  my ($self, $Rs, $opt) = @_;
  
  return $Rs unless (ref($opt)||'' eq 'HASH');
  my $query = $opt->{query} or return $Rs;
  
  my @words = split(/\s+/,$query);
  
  my @search = map {
    $self->_get_query_condition_list($Rs,{ %$opt, query => $_ }) || ()
  } @words;
  
  # If no search conditions have been populated at all it means the query
  # failed pre-validation for all active columns. We need to simulate
  # a condition which will return no rows
  unless(scalar(@search) > 0) {
    # Simple dummy condition that will always be false to force 0 results
    return $Rs->search_rs(\'1 = 2');
  }
  
  return $self->_call_search_rs($Rs,{ '-or' => \@search })
}



1;