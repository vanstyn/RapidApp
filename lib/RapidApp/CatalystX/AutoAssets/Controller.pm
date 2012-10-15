package RapidApp::CatalystX::AutoAssets::Controller;
our $VERSION = '0.01';
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use RapidApp::Include qw(sugar perlutil);

use Switch qw(switch);


has 'minify_dir', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my $c = $self->_app;
	return $c->config->{home} . '/minified_assets';
};


sub index :Path :Args(1) {
    my ( $self, $c, $filename ) = @_;
	
	my ($checksum,$ext) = split(/\./,$filename,2);
	my $fh = $self->get_asset_fh($c,$filename,$checksum) or return $self->unknown_asset($c);
	
	# Set the Content-Type according to the extention - only 'js' or 'css' current supported:
	switch($ext) {
		case 'js'	{ $c->response->header( 'Content-Type' => 'text/javascript' ); }
		case 'css' 	{ $c->response->header( 'Content-Type' => 'text/css' ); }
		else 		{ return $self->unknown_asset($c); }
	}
	
    return $c->response->body( $fh );
}


sub get_asset_fh {
	my ($self,$c,$filename,$checksum) = @_;
	
	
	return undef;

}

sub unknown_asset {
	my ($self,$c) = @_;
	$c->res->status(404);
	return $c->res->body('Unknown asset');
}

1;
