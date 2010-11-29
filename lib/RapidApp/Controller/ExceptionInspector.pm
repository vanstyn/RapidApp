package RapidApp::Controller::ExceptionInspector;

use Moose;
extends 'RapidApp::AppBase';

use Try::Tiny;
use Storable qw(freeze thaw);
use Data::Dumper;
use RapidApp::Error;
use RapidApp::UserError;

# make sure the as_html method gets loaded into StackTrace, which might get deserialized
use Devel::StackTrace;
use Devel::StackTrace::WithLexicals;
use Devel::StackTrace::AsHTML;

has 'exceptionModel' => ( is => 'rw', isa => 'Str', default => 'DB::exception' );

sub BUILD {
	my $self= shift;
	$self->auto_viewport(1);
	$self->apply_actions(justdie => 'justdie', diefancy => 'diefancy', usererror => 'usererror');
}

sub viewport {
	my $self= shift;
	
	my $id= $self->c->req->params->{id};
	try {
		defined $id or die "No ID specified";
		my $info= $self->loadExceptionInfo($id);
		$self->c->stash->{ex}= $info;
	}
	catch {
		use Data::Dumper;
		$self->c->log->debug(Dumper(keys %$_));
		$self->c->stash->{ex}= { id => $id, error => $_ };
	};
	$self->c->stash->{current_view}= 'RapidApp::TT';
	$self->c->stash->{template}= 'templates/rapidapp/exception.tt';
}

sub justdie {
	die "Deliberately generating an exception";
}

sub diefancy {
	die RapidApp::Error->new("Generating an exception using the RapidApp::Error class");
}

sub usererror {
	die RapidApp::UserError->new("PEBKAC");
}

=head2 loadExceptionInfo($id)

Loads the exception for ID, and returns it in a hash, merged with the hash which was serialized
into the database.

=cut
sub loadExceptionInfo {
	my ($self, $id)= @_;
	
	my $rs= $self->c->model($self->exceptionModel);
	my $row= $rs->find($id);
	defined $row or die "No excption exists for id $id";
	my $infoHash= thaw($row->why) || {};
	
	my $result= {
		$row->get_inflated_columns,
		%$infoHash,
	};
	delete $result->{why};
	
	# convert the time zone ot local time (of the server)
	if ($result->{when}) {
		#$self->c->log->debug("DateTime: " . Dumper($result->{when}));
		#ref $result->{when} or $result->{when}= DateTime->new($result->{when}
		$result->{when}->set_time_zone("UTC");
		$result->{when}->set_time_zone("local");
		
		#$self->c->log->debug("DateTime: " . Dumper($result->{when}));
	}
	return $result;
}

1;
