# Content object class
package RapidApp::CatalystX::SimpleCAS::Content;
use Moose;

use RapidApp::Include qw(sugar perlutil);
use Email::MIME;

has 'Store', is => 'ro', required => 1, isa => 'Object';
has 'checksum', is => 'ro', required => 1, isa => 'Str';
has 'filename', is => 'ro', isa => 'Maybe[Str]', default => undef;

sub BUILD {
	my $self = shift;
	die "Content does not exist" unless ($self->Store->content_exists($self->checksum));
}

has 'MIME' => (
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;

		my $attrs = {
			content_type => $self->mimetype,
			encoding => 'base64'
		};
		$attrs = { %$attrs, 
			filename => $self->filename,
			name => $self->filename
		} if ($self->filename);
	
		return Email::MIME->create(
			attributes => $attrs,
			body => $self->content
		);

	}
);

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

sub content {
	my $self = shift;
	return $self->Store->fetch_content($self->checksum);
}

1;
