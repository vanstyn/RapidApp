package Catalyst::Plugin::RapidApp::NavCore::Controller;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' };

use RapidApp::Include qw(sugar perlutil);
require Module::Runtime;
require Catalyst::Utils;

use JSON qw(decode_json);

# Controller for loading a saved search in CoreSchema via ID


sub load :Path :Args(1) {
  my ( $self, $c, $search_id ) = @_;
  
  ### -----------------
  ### NEW: detect direct browser GET requests (i.e. not from the ExtJS client):
  ### and redirect them back to the #! hashnav path
  if ($c->req->method eq 'GET' && ! $c->req->header('X-RapidApp-RequestContentType')) {
    my $url = join('/','/#!',$self->action_namespace($c),$search_id);
    my %params = %{$c->req->params};
    if(keys %params > 0) {
      my $qs = join('&',map { $_ . '=' . uri_escape($params{$_}) } keys %params);
      $url .= '?' . $qs;
    }
    
    $c->response->redirect($url);
    return $c->detach;
  }
  ###
  ### -----------------

  my $Rs = $c->model('RapidApp::CoreSchema::SavedState');
  
  my $Row = $Rs->find($search_id) or die usererr "Search ID $search_id not found.";

	my $data = { $Row->get_columns };
	
	# TODO: enforce permissions
  

	$c->stash->{apply_extconfig} = {
		tabTitle => $data->{title},
		tabIconCls => $data->{iconcls}
	};
	
	my $params = decode_json($data->{params});
	
	my @not_allowed_params = qw(search_id quick_search quick_search_cols);
	exists $params->{$_} and delete $params->{$_} for (@not_allowed_params);
	
	$params->{search_id} = $data->{id};
	
	%{$c->req->params} = ( %{$c->req->params}, %$params );
	$data->{url} =~ s/^\///; #<-- strip leading / (needed for split below)
	my @arg_path = split(/\//,$data->{url});
	
	$c->detach('/approot',\@arg_path);
}





1;


