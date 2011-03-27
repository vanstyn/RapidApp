package RapidApp::CatalystX::SimpleCAS::Controller;
our $VERSION = '0.01';
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use RapidApp::CatalystX::SimpleCAS::Store::Git;

has 'Store' => (
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		return RapidApp::CatalystX::SimpleCAS::Store::Git->new(
			git_dir => '/root/RapidApps/GreenSheet/simplecas-store'
		);
	}
);

sub fetch_content: Local {
    my ($self, $c, $sha1) = @_;
	
	use Data::Dumper;
	
	print STDERR Dumper($self->Store->GitRepo);
	
	unless($self->Store->content_exists($sha1)) {
		$c->res->body('Does not exist');
		return;
	}
	
	my $type = $self->Store->content_mimetype($sha1) or die "Error reading mime type";
	
	$c->response->header('Content-Type' => $type);
	$c->response->header('Content-Disposition' => 'inline;filename="' . $sha1 . '"');
	return $c->res->body( $self->Store->fetch_content_fh($sha1) );
}


1;
