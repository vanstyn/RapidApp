package RapidApp::View::JSON;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::View'; }

use RapidApp::JSON::MixedEncoder;

has 'encoding' => ( is => 'rw', isa => 'Str' );

has 'encoder' => ( is => 'rw', isa => 'RapidApp::JSON::MixedEncoder', lazy_build => 1 );
sub _build_encoder {
	return RapidApp::JSON::MixedEncoder->new
}

sub process {
	my ($self, $c)= @_;
	
	my $jsonStr;
	
	my $encoding= $self->encoding || 'utf-8';
	$c->res->content_type("application/json; charset=$encoding");
	
	$c->res->header('Cache-Control' => 'no-cache');
	
	if ($c->stash->{exception}) {
		$c->res->header('X-RapidApp-Exception' => 1);
		$c->res->status(542);
		
		# clean up the message a bit
		my $msg= $c->stash->{exception};
		$msg =~ s|\n|<br/>|g;
		if (length($msg) > 300) {
			$msg= substr($msg, 0, 300).' ...';
		}
		
		$jsonStr= $self->encoder->encode_json({
			exception	=> \1,
			success		=> \0,
			msg			=> $msg
		});
	}
	elsif (defined $c->stash->{jsonData}) {
		$jsonStr= $self->encoder->encode_json($c->stash->{jsonData});
	}
	elsif (defined $c->stash->{json}) {
		$jsonStr= $c->stash->{json};
	}
	elsif (defined $c->stash->{controllerResult}) {
		if (!ref $c->stash->{controllerResult}) {
			$jsonStr= $c->stash->{controllerResult};
		} else {
			$jsonStr= $self->encoder->encode_json($c->stash->{controllerResult});
		}
	}
	else {
		die "None of exception, jsonData, json, controllerResult were specified.  Cannot render.";
	}
	
	$c->res->body($jsonStr);
}

1;
