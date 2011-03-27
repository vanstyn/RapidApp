package RapidApp::CatalystX::SimpleCAS::Controller;
our $VERSION = '0.01';
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use RapidApp::CatalystX::SimpleCAS::Store::File;

has 'Store' => (
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		return RapidApp::CatalystX::SimpleCAS::Store::File->new(
			store_dir => '/root/RapidApps/GreenSheet/file_cas'
		);
	}
);

sub fetch_content: Local {
    my ($self, $c, $checksum) = @_;
	
	unless($self->Store->content_exists($checksum)) {
		$c->res->body('Does not exist');
		return;
	}
	
	my $type = $self->Store->content_mimetype($checksum) or die "Error reading mime type";
	
	$c->response->header('Content-Type' => $type);
	$c->response->header('Content-Disposition' => 'inline;filename="' . $checksum . '"');
	return $c->res->body( $self->Store->fetch_content_fh($checksum) );
}


1;
