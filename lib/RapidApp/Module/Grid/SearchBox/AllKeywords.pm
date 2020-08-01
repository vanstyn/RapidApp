package RapidApp::Module::Grid::SearchBox::AllKeywords;

use strict;
use warnings;

use Moo;
extends 'RapidApp::Module::Grid::SearchBox::Normal';
use Types::Standard ':all';

use RapidApp::Util qw(:all);

has '+documentation', default => sub { join(" ",
  'Like Keyword search (Any), but requires that *all* of the supplied keywords be found for',
  'a given record to be returned in the result set'
)};


has '+mode_name',       default => sub { 'all_keyword' };
has '+label',           default => sub { 'Search Keywords (all)' };
has '+menu_text',       default => sub { 'Keywords (All)' };


sub chain_query_search_rs {
  my ($self, $Rs, $opt) = @_;
  
  return $Rs unless (ref($opt)||'' eq 'HASH');
  my $query = $opt->{query} or return $Rs;
  
  my @words = split(/\s+/,$query);
  
  my @search = ();
  for my $word (@words) {
    my @set = $self->_get_query_condition_list($Rs,{ %$opt, query => $word }) || ();
    next unless (scalar(@set) > 0);
    push @search, { '-or' => \@set };
  }
  
  # If no search conditions have been populated at all it means the query
  # failed pre-validation for all active columns. We need to simulate
  # a condition which will return no rows
  unless(scalar(@search) > 0) {
    # Simple dummy condition that will always be false to force 0 results
    return $Rs->search_rs(\'1 = 2');
  }
  
  return $self->_call_search_rs($Rs,{ '-and' => \@search })
}



1;