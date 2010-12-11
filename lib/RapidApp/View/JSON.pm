package RapidApp::View::JSON;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::View'; }

use RapidApp::JSON::MixedEncoder;
use Data::Dumper;

has 'encoding' => ( is => 'rw', isa => 'Str', default => 'utf-8' );

has 'encoder' => ( is => 'rw', isa => 'RapidApp::JSON::MixedEncoder', lazy_build => 1 );
sub _build_encoder {
	return RapidApp::JSON::MixedEncoder->new
}

sub process {
	my ($self, $c)= @_;
	
	my $jsonStr;
	
	my $encoding= $c->stash->{encoding} || $self->encoding;
	#$c->res->content_type("application/json; charset=$encoding");
	
	$c->res->header('Cache-Control' => 'no-cache');
	
	if ($c->stash->{exception}) {
		my $err= $c->stash->{exception};
		
		$c->res->header('X-RapidApp-Exception' => 1);
		$c->res->status(542);
		
		my $msg;
		if ($c->stash->{isUserError}) {
			$msg= $err->userMessage;
			$msg =~ s|\n|<br/>|g;
			$msg =~ s|&|&amp;|g;
			$msg =~ s|<|&lt;|g;
			$msg =~ s|>|&gt;|g;
			$msg =~ s|"|&quot;|g;
		}
		else {
			$msg= 'An internal error occured<br/>';
		}
		
		if ($c->stash->{exceptionRefId}) {
			my $id= $c->stash->{exceptionRefId};
			$msg .= 'The details of this error have been kept for analysis<br/>'
				.'Reference number ';
			if ($c->debug && $c->r->errorViewPath) {
				$msg .= '<a href="/'.$c->r->errorViewPath.'/view?id='.$id.'" target="_blank">'.$id.'</a>';
			} else {
				$msg .= $id;
			}
		}
		elsif (defined $c->stash->{exceptionRefId}) {
			$msg .= "The details of this error could not be saved.";
		}
		
		$jsonStr= $self->encoder->encode({
			exception	=> \1,
			success		=> \0,
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
	
	$c->res->body($jsonStr);
}

1;
