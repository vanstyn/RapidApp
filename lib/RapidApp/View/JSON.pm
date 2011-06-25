package RapidApp::View::JSON;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::View'; }

use RapidApp::JSON::MixedEncoder;
use Data::Dumper;
use Scalar::Util 'blessed', 'reftype';
use HTML::Entities;
use RapidApp::Sugar;

has 'encoding' => ( is => 'rw', isa => 'Str', default => 'utf-8' );

has 'encoder' => ( is => 'rw', isa => 'RapidApp::JSON::MixedEncoder', lazy_build => 1 );
sub _build_encoder {
	return RapidApp::JSON::MixedEncoder->new
}

sub process {
	my ($self, $c)= @_;
	
	my ($json, $formCfg);
	
	if ($c->stash->{exception}) {
		my $err= $c->stash->{exception};
		DEBUG('controller', 'JSON->process( exception == '.$err.' )');
		
		$c->res->header('X-RapidApp-Exception' => 1);
		$c->res->status(500);
		
		my $msg= $self->getUserMessage($err) || 'An internal error occured';
		my $title= $self->getUserMessageTitle($err) || 'Error';
		
		# This flag prevents infinite error reporting if adding a comment throws an error
		# See Role::CatalystApplication
		if ($c->stash->{exceptionFailedToAddComment}) {
			$msg = "Unable to add your message to the error report.<br/>However, The error has still been reported.";
		}
		# If exceptionRefId exists, we mention something about it to the user.
		# If it is false, this means we failed to save it.
		elsif ($c->stash->{exceptionRefId}) {
			my $id= $c->stash->{exceptionRefId};
			$msg .= '<br/>The details of this error have been kept for analysis<br/>'
				.'Reference number ';
			if ($c->debug && $c->rapidApp->errorViewPath) {
				$msg .= '<a href="'.$c->rapidApp->errorViewPath.'/?id='.$id.'" target="_blank">'.$id.'</a>';
			} else {
				$msg .= $id;
			}
			if ($c->stash->{exceptionPromptForComment}) {
				$formCfg= {
					title => $title,
					height => 250,
					width => 370,
					url => $c->rapidApp->errorAddCommentPath .'/addComment',
					params => { errId => $c->stash->{exceptionRefId} },
					fieldset => {
						xtype => 'fieldset',
						style => 'border: none',
						hideBorders => \1,
						labelWidth => 80,
						border => \0,
						items => [
							{ xtype => 'box', html => $msg },
							{ xtype => 'spacer', height => '1em' },
							{ xtype => 'box', html => 'Please describe what you were doing, so that we might better diagnose the problem' },
							{ xtype => 'spacer', height => '0.1em' },
							{ xtype => 'textarea', name => 'comment', hideLabel => 1, height => '4em', width => 300 },
						],
					},
					closable => \0,
					submitBtnText => 'Ok',
				};
			}
		}
		elsif (exists $c->stash->{exceptionRefId}) {
			$msg .= "<br/>The details of this error could not be saved.";
		}
		$json= {
			exception   => \1,
			success		=> \0,
			rows			=> [],
			results		=> 0,
			msg			=> $msg,
			title       => $title,
			winform     => $formCfg,
		};
	}
	else {
		$json= $c->stash->{json} || $c->stash->{jsonData} || $c->stash->{controllerResult}
			or die "None of exception, json, jsonData, controllerResult were specified.  Cannot render.";
	}
	
	$self->setJsonBody($c, $json);
}

sub setJsonBody {
	my ($self, $c, $json)= @_;
	
	my $encoding= $c->stash->{encoding} || $self->encoding;
	my $rct= $c->stash->{requestContentType};
	DEBUG('controller', 'rendering json for request content type ', $rct, json => $json);
	
	(!ref $json) or $json= $self->encoder->encode($json);
	
	$c->res->header('Cache-Control' => 'no-cache');
	
	if ($rct eq 'text/x-rapidapp-form-response') {
		my $hdr= $c->res->headers;
		my %headers= map { $_ => $hdr->header($_) } $hdr->header_field_names;
		my $headerJson= $self->encoder->encode(\%headers);
		
		$c->res->content_type("text/html; charset=$encoding");
		$c->res->body(
			'<html><body>'.
				'<textarea id="json">'.encode_entities($json).'</textarea>'.
				'<textarea id="header_json">'.encode_entities($headerJson).'</textarea>'.
			'</body></html>'
		);
	}
	else {
		$c->res->content_type("text/javascript; charset=$encoding");
		$c->res->body($json);
	}
}

sub getUserMessage {
	my ($self, $err)= @_;
	blessed($err) or return undef;
	my $method= $err->can('userMessage') || return undef;
	my $str= ashtml $err->$method();
	defined $str && length($str) or return undef;
	return $str;
}

sub getUserMessageTitle {
	my ($self, $err)= @_;
	blessed($err) or return undef;
	my $method= $err->can('userMessageTitle') || return undef;
	my $str= ashtml $err->$method();
	defined $str && length $str or return undef;
	return $str;
}

1;
