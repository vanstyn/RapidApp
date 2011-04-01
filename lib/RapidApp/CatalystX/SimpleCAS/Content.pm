# Content object class
package RapidApp::CatalystX::SimpleCAS::Content;
use Moose;


has 'Store' => ( is => 'ro', required => 1, isa => 'Object' );
has 'checksum' => ( is => 'ro', required => 1, isa => 'Str' );

sub BUILD {
	my $self = shift;
	die "Content does not exist" unless ($self->Store->content_exists($self->checksum));
}

has 'mimetype' => (
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		return $self->Store->content_mimetype($self->checksum);
	}
);

has 'image_size' => (
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		my ($width,$height) = $self->Store->image_size($self->checksum);
		return [$width,$height];
	}
);


has 'size' => (
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		return $self->Store->content_size($self->checksum);
	}
);


sub fh {
	my $self = shift;
	return $self->Store->fetch_content_fh($self->checksum);
}




1;
