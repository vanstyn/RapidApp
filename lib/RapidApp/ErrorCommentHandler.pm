package RapidApp::ErrorCommentHandler;

use Moose;
extends 'RapidApp::AppBase';

use RapidApp::Include qw(perlutil sugar);

has 'errorReportStore' => ( is => 'rw', isa => 'Maybe[RapidApp::Role::ErrorReportStore|Str]' );

sub resolveErrorReportStore {
	my $self= shift;
	
	my $store= $self->errorReportStore;
	$store ||= $self->app->rapidApp->resolveErrorReportStore;
	
	defined $store or die "No ErrorReportStore configured";
	return (ref $store? $store : $self->app->model($store));
}

override_defaults(
	auto_web1 => 1,
);

sub BUILD {
	my $self= shift;
	
	# Register ourselves with RapidApp if no other has already been registered
	# This affects there the user comments are directed for all error reports.
	defined $self->app->rapidApp->errorAddCommentPath
		or $self->app->rapidApp->errorAddCommentPath($self->module_path);
	
	$self->apply_actions(
		addComment => 'addComment',
	);
}

sub addComment {
	my $self= shift;
	
	my $errId= $self->c->req->params->{errId};
	my $comment= $self->c->req->params->{comment};
	if (defined $comment && length $comment) {
		my $errStore= $self->resolveErrorReportStore or die "No report store configured";
		my $report= $errStore->loadErrorReport($errId) or die "No such error report";
		defined $report->userComment and die "Comment was already added";
		
		if ($self->c->user && defined $self->c->user->id && defined $report->debugInfo->{uid}) {
			$self->c->user->id eq $report->debugInfo->{uid} or die "You may only comment on your own errors";
		}
		
		$report->userComment($comment);
		$errStore->updateErrorReport($errId, $report);
	}
	
	defined $comment
}

1;
