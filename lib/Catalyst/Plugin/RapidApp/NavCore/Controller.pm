package Catalyst::Plugin::RapidApp::NavCore::Controller;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' };

use RapidApp::Util qw(:all);
require Module::Runtime;
require Catalyst::Utils;

use JSON::MaybeXS qw(decode_json);

# Controller for loading a saved search in CoreSchema via ID

sub load :Chained :PathPart('view') :Args(1) {
  my ( $self, $c, $search_id ) = @_;
  
  ## ---
  ## detect direct browser GET requests (i.e. not from the ExtJS client)
  ## and redirect them back to the #! hashnav path
  $c->auto_hashnav_redirect_current;
  # ---

  my $Rs = $c->model('RapidApp::CoreSchema::SavedState');
  
  my $Row = $Rs->find($search_id) or die usererr "Search ID $search_id not found.";

	my $data = { $Row->get_columns };
	
	# TODO: enforce permissions
  

	$c->stash->{apply_extconfig} = {
		tabTitle => $data->{title},
		tabIconCls => $data->{iconcls}
	};
	
	my $params = $data->{params} ? decode_json($data->{params}) : {};
	
	my @not_allowed_params = qw(search_id quick_search quick_search_cols quick_search_mode);
	exists $params->{$_} and delete $params->{$_} for (@not_allowed_params);
	
	$params->{search_id} = $data->{id};
	
	%{$c->req->params} = ( %{$c->req->params}, %$params );
  return $c->redispatch_public_path( $data->{url} );

  ## This is how we did it before $c->redispatch_public_path():
  #$data->{url} =~ s/^\///; #<-- strip leading / (needed for split below)
  #my @arg_path = split(/\//,$data->{url});
  #$c->detach('/approot',\@arg_path);
}





1;


