package RapidApp::Role::DbicDataStore;



### THIS IS NOT FINISHED OR WORKING ###



use strict;
use Moose::Role;
with 'RapidApp::Role::DataStore';

use RapidApp::DbicExtQuery;


has 'ResultSource' 				=> ( is => 'ro', required => 1 );
has 'fieldname_transforms'		=> ( is => 'ro', default => sub {{}} );
has 'joins'							=> ( is => 'ro', default => sub {[]} );

has 'DbicExtQuery' => ( is => 'ro', lazy_build => 1 );
sub _build_DbicExtQuery {
	my $self = shift;
	
	return RapidApp::DbicExtQuery->new(
		ResultSource => $self->ResultSource,
		ExtNamesToDbFields => $self->fieldname_transforms,
		joins => $self->joins
	);
}

has 'record_pk' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my @keys = $self->ResultSource->primary_columns;
	return shift @keys;
});

has 'read_records_coderef' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return sub {
	
		my $params = $self->c->req->params;
		
		my $data = $self->DbicExtQuery->data_fetch({ 
			Search_spec	=> { 'me.' . $self->record_pk => $params->{$self->record_pk}	},
		});
		
		my $row = shift @{$data->{rows}};
		
		return {
			rows			=> [ { $row->get_columns } ],
			results		=> 1
		};
	};
});


has 'update_records_coderef' => ( is => 'ro', lazy_build => 1 );
sub _build_update_records_coderef {
	my $self = shift;
	return sub {

		my $params = shift;
		my $orig_params = shift;

		my $dt = DateTime->now( time_zone => 'EST5EDT' );
		
		#$params->{update_timestamp} = $dt;
		#$params->{update_user_id} = $self->App->fetch_current_user_id($self->c);
		#$params->{update_username} = $self->c->user->get('username');
		
		
		
		#use Data::Dumper;
		#print STDERR YELLOW . BOLD . Dumper($params) . CLEAR;
		
		

		#my $Row = $self->App->Schema->resultset('Request')->search($orig_params) or die 'failed to find - ' . $orig_params->{id};
		my $Row = $self->c->model("DB")->resultset('Project')->find($orig_params->{$self->item_key}) 
			or die 'failed to find - ' . $orig_params->{$self->item_key};

		$self->update_row_with($Row,$params) and return {
			success	=> \1,
			msg		=> 'Success'
		};
		
		return {
			success	=> \0,
			msg		=> 'Failed'
		};

	};
}

sub update_row_with {
	my $self = shift;
	my $row = shift;
	my $params = shift or die "No params passed";
	
	my $new_data = {};
	
	my %cols = $row->get_columns;
	foreach my $k (keys %cols) {
		$new_data->{$k} = $params->{$k} if (defined $params->{$k});
	}
	
	my $result;
	
	my $uid = $self->App->fetch_current_user_id($self->c);
	$self->c->model("DB")->changeset_user($uid);
	
	$self->c->model("DB")->txn_do( sub {
		$result = $row->update($new_data) or return undef; 
	});
	#$self->reset_attr;
	return $result;
}




#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;