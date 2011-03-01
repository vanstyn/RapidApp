package RapidApp::View::JSON;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::View'; }

use RapidApp::JSON::MixedEncoder;
use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';
use HTML::Entities;

has 'encoding' => ( is => 'rw', isa => 'Str', default => 'utf-8' );

has 'encoder' => ( is => 'rw', isa => 'RapidApp::JSON::MixedEncoder', lazy_build => 1 );
sub _build_encoder {
	return RapidApp::JSON::MixedEncoder->new
}

sub process {
	my ($self, $c)= @_;
	
	my $jsonStr;
	
	my $encoding= $c->stash->{encoding} || $self->encoding;
	my $rct= $c->stash->{requestContentType};
	
	if ($rct eq 'text/x-rapidapp-form-response') {
		$c->res->content_type("text/html; charset=$encoding");
	}
	elsif ($rct eq 'JSON') {
		$c->res->content_type("application/json; charset=$encoding");
	}
	else {
		$c->res->content_type("text/plain; charset=$encoding");
	}
	
	$c->res->header('Cache-Control' => 'no-cache');
	
	if ($c->stash->{exception}) {
		$c->stash->{exception}->isa('RapidApp::Responder::UserError')
			and RapidApp::ScopedGlobals->log->warn("UserError didn't get to do its own rendering!");
		
		my $err= $c->stash->{exception};
		
		$c->res->header('X-RapidApp-Exception' => 1);
		$c->res->status(500);
		
		my $msg= $self->getUserMessage($err) || 'An internal error occured';
		
		# If exceptionRefId exists, we mention something about it to the user.
		# If it is false, this means we failed to save it.
		if ($c->stash->{exceptionRefId}) {
			my $id= $c->stash->{exceptionRefId};
			$msg .= '<br/>The details of this error have been kept for analysis<br/>'
				.'Reference number ';
			if ($c->debug && $c->rapidApp->errorViewPath) {
				$msg .= '<a href="'.$c->rapidApp->errorViewPath.'/?id='.$id.'" target="_blank">'.$id.'</a>';
			} else {
				$msg .= $id;
			}
		}
		elsif (exists $c->stash->{exceptionRefId}) {
			$msg .= "<br/>The details of this error could not be saved.";
		}
		
		$jsonStr= $self->encoder->encode({
			($rct eq 'text/x-rapidapp-form-response'? ('X-RapidApp-Exception' => 1) : ()),
			exception   => \1,
			success		=> \0,
			rows			=> [],
			results		=> 0,
			msg			=> $msg
		});
	}
	elsif (defined $c->stash->{jsonData}) {
		$jsonStr= $self->encoder->encode($c->stash->{jsonData});
	}
	elsif (defined $c->stash->{json}) {
		$jsonStr= $c->stash->{json};
	}
	elsif (defined $c->stash->{controllerResult}) {
		my $data= $c->stash->{controllerResult};
		$jsonStr= ref $data? $self->encoder->encode($data) : $data;
	}
	else {
		die "None of exception, jsonData, json, controllerResult were specified.  Cannot render.";
	}
	
	# The ExtJS form submission must be delivered as encoded HTML, so that ExtJS can extract the string from the IFrame
	if ($rct eq 'text/x-rapidapp-form-response') {
		$jsonStr= encode_entities($jsonStr);
	}
	
	$c->res->body($jsonStr);
}

sub getUserMessage {
	my ($self, $err)= @_;
	blessed($err) or return undef;
	my $method= $err->can('userMessage') || return undef;
	my $str= $err->$method();
	defined $str && length($str) or return undef;
	return join('<br/>', encode_entities(split '\n', $str));
}

1;
