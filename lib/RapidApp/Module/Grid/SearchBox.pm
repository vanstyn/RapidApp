package RapidApp::Module::Grid::SearchBox;

use strict;
use warnings;

use Moo;
use Types::Standard ':all';

use RapidApp::Util qw(:all);

has 'grid_module', 
  is => 'ro', 
  isa => ConsumerOf['RapidApp::Module::StorCmp::Role::DbicLnk'], 
  required => 1;


has 'loaded_order',   
  is => 'ro', 
  isa => Int,  
  default => sub { 0 };

has 'mode_name', 
  is => 'ro', 
  isa => Str,  
  required => 1;
  
has 'label',
  is => 'ro',
  isa => Str,
  required => 1;

has 'menu_text',
  is => 'ro',
  isa => Str,
  default => sub { undef };

# TODO: 'choose_columns' option not yet implemented  
has 'choose_columns',
  is => 'ro', 
  isa => Bool, 
  required => 1;


# Plain text description of how the given search mode works. Shown
# to the user via new About menu point
has 'documentation',
  is => 'ro',
  isa => Str,
  required => 1;

## Idea feature for future; arbirarary type-ahead functionality
#has 'type_ahead',
#  is => 'ro', 
#  isa => Bool, 
#  default => sub { 0 };



# Every subclass must implement this method:

=head2 chain_query_search_rs

  $modified_resultset = $searchbox->chain_query_search_rs( $resultset, $params );
  # where $params may contain:
  {
    query => $search_text,
    columns => \@column_name_list,
  }

This method is called by the Grid to apply the QuickSearch query information in
C<$params> to the C<$resultset>, returning a chained C<$modified_resultset>.

If the C<$params> do not contain a C<'query'> string, this returns the C<$resultset>
un-changed.  If the C<$params> describe a search that does not search any columns,
this method returns a resultset that finds zero rows.

=cut

sub chain_query_search_rs {
  my ($self, $Rs, $opt) = @_;
  
  die "Unimplemented";
}


# Private method entry point - sub classes should not override this:
sub _chain_query_search_rs {
  my $self = shift;
  
  # This is used to "follow" the joins that are needed as conditions
  # are built iteratively. We do it this way in order to avoid needing
  # to modify/chain the ResultSet object more than a single, real/actual 
  # time. This is the same way it worked prior to the SerchBox refactor,
  # but it just wasn't explained in a comment like this until now
  local $self->{__current_attr} = { join => {} };
  
  $self->chain_query_search_rs(@_)
}


# This method exists to provide a simpler way for sub classes to call the chained
# Rs method without having to supply the attr argument containing the joins which
# are needed for the search conditions. 
sub _call_search_rs {
  my ($self, $Rs, $cond, $attr) = @_;
  
  $attr ||= $self->{__current_attr};
  return $self->grid_module->_chain_search_rs($Rs,$cond,$attr);
}


sub _enforce_valid_opt {
  my ($self, $opt) = @_;
  die "invalid or no options supplied" unless (ref($opt)||'' eq 'HASH');
  die "missing required query option 'query'" unless $opt->{query};
  if($self->choose_columns) {
    die "missing required ArrayRef option 'columns'" unless (ref($opt->{columns})||'' eq 'ARRAY');
    die "empty list of columns supplied" unless (scalar(@{$opt->{columns}}) > 0);
  }
}






sub searchbox_ext_config {
  my $self = shift;

  return {
    mode_name       => $self->mode_name,
    label           => $self->label,
    menu_text       => $self->menu_text || $self->label,
    choose_columns  => $self->choose_columns ? \1 : \0,
    documentation   => $self->documentation
  }
}



1;
