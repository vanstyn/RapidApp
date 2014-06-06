package RapidApp::CoreSchema::ResultSet::Request;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

use RapidApp::Include qw(sugar perlutil);

# Flexible handling (copied from My Clippard)
sub record_Request {
	my $self = shift;
	my $ReqData = shift or die "Missing Request Data";
	my $extra = shift || {};
  
  # Also support full Catalyst Context arg:
  my $c = (
    blessed $ReqData && 
    $ReqData->can('request') &&
    $ReqData->request->isa('Catalyst::Request')
  ) ? $ReqData : undef;
  $ReqData = $c->request if ($c);
  
	
	my $dt = $extra->{unix_timestamp} ? 
		DateTime->from_epoch(epoch => $extra->{unix_timestamp}, time_zone => 'local') : 
			DateTime->now( time_zone => 'local' );
	
	my $data = {
		timestamp => $dt->ymd . ' ' . $dt->hms(':'),
		serialized_request => $extra->{full_request_yaml} || ''
	};
	
	if(ref $ReqData eq 'HASH') {
		%$data = ( %$data,
			client_ip => $ReqData->{address} || $ReqData->{client_ip},
			uri => $ReqData->{uri},
			method => $ReqData->{method},
			user_agent => $ReqData->{user_agent},
			referer => $ReqData->{referer},
		);
	}
	elsif(try{$ReqData->isa('Catalyst::Request')}) {
		%$data = ( %$data,
			client_ip => ($ReqData->address || undef),
			uri => ($ReqData->uri || undef),
			method => ($ReqData->method || undef),
			user_agent => ($ReqData->header('user-agent') || undef),
			referer => ($ReqData->header('referer') || undef),
		);
    $data->{user_id} = $c->user->get_column('id') if ($c && try{$c->user});
	}
	else {
		die "Expected Request Data as either a Hash or Catalyst::Request object";
	}
  
  return $self->create($data) if(defined wantarray);
  
  # populate for speed in VOID context:
	$self->populate([$data]);
  return 1;
}

# Records the request from the catalyst context object ($c)
sub record_ctx_Request {
	my $self = shift;
	my $c = shift or return undef;
  
  my $Request = $c->request or return undef;
  
  my $data = {
    client_ip => ($Request->address || undef),
    uri => ($Request->uri || undef),
    method => ($Request->method || undef),
    user_agent => ($Request->header('user-agent') || undef),
    referer => ($Request->header('referer') || undef),
    timestamp => DateTime->now( time_zone => 'local' )
  };

  return $self->create($data) if(defined wantarray);
  
  # populate for speed in VOID context:
	$self->populate([$data]);
  return 1;
}


1;