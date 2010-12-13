package RapidApp::Role::DataStore2::SavedSearch;


use strict;
use Moose::Role;


use Try::Tiny;

#### --------------------- ####

sub BUILD {}
before 'BUILD' => sub {
	my $self = shift;
	$self->add_ONREQUEST_calls_early('run_load_saved_search');
};


sub run_load_saved_search {
	my $self = shift;
	
	return unless ($self->can('load_saved_search'));
	
	try {
		$self->Module('store'); # <-- Make sure store has already called ONREQUEST
		$self->load_saved_search;
	}
	catch {
		my $err = $_;
		$self->set_response_warning({
			title	=> 'Error loading search',
			msg	=> 
				'An error occured while trying to load the saved search. The default view has been loaded.' . "\n\n" . 
				'DETAIL:' . "\n\n" .
				'<pre>' . $err . '</pre>'
		});
	};
}


no Moose;
#__PACKAGE__->meta->make_immutable;
1;