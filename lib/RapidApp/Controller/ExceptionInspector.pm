package RapidApp::Controller::ExceptionInspector;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; }

use RapidApp::Include qw(perlutil sugar);
use Storable qw(freeze thaw);
use RapidApp::Sugar;

# make sure the as_html method gets loaded into StackTrace, which might get deserialized
use Devel::StackTrace;
use Devel::StackTrace::WithLexicals;
use Devel::StackTrace::AsHTML;

__PACKAGE__->config( namespace => '/exception' );

has 'exceptionStore' => ( is => 'rw' ); # either a store object, or a Model name

sub view :Local {
	my ($self, $c, @args)= @_;
	
	my $id= $self->c->req->params->{id};
	try {
		defined $id or die "No ID specified";
		
		my $store= $self->exceptionStore;
		defined $store or die "No ExceptionStore configured";
		ref $store or $store= $c->model($store);
		
		my $err= $store->loadException($id);
		$self->c->stash->{ex}= $err;
	}
	catch {
		use Data::Dumper;
		$self->c->log->debug(Dumper(keys %$_));
		$self->c->stash->{ex}= { id => $id, error => $_ };
	};
	$self->c->stash->{current_view}= 'RapidApp::TT';
	$self->c->stash->{template}= 'templates/rapidapp/exception.tt';
}

sub justdie :Local {
	die "Deliberately generating an exception";
}

sub diefancy :Local {
	die RapidApp::Error->new("Generating an exception using the RapidApp::Error class");
}

sub usererror :Local {
	die usererr "PEBKAC";
}

1;
