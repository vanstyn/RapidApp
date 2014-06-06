# Content object class
package RapidApp::CatalystX::SimpleCAS::Content;
use Moose;

use RapidApp::Include qw(sugar perlutil);
use Email::MIME;
use Image::Size;

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

# TODO: abstract this properly and put it in the right place
has 'fetch_url_path', is => 'ro', isa => 'Str', default => '/simplecas/fetch_content/';

has 'src_url', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my $url = $self->fetch_url_path . $self->checksum;
	$url .= '/' . $self->filename if ($self->filename);
	return $url;
};

has 'file_ext', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return undef unless ($self->filename);
	my @parts = split(/\./,$self->filename);
	return undef unless (scalar @parts > 1);
	return lc(pop @parts);
};

has 'filelink_css_class', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my @css_class = ('filelink');
	push @css_class, $self->file_ext if ($self->file_ext);
	return join(' ',@css_class);
};

has 'filelink', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my $name = $self->filename || $self->checksum;
	return '<a class="' . $self->filelink_css_class . '" ' .
		' href="' . $self->src_url . '">' . $name . '</a>';
};

has 'img_size', is => 'ro', lazy => 1, default => sub {
	my $self = shift;

	my $content_type = $self->mimetype or return undef;
	my ($mime_type,$mime_subtype) = split(/\//,$content_type);
	return undef unless ($mime_type eq 'image');
	
	my ($width,$height) = imgsize($self->Store->checksum_to_path($self->checksum)) or return undef;
	#return ($width,$height);
	return { height => $height, width => $width };
};

has 'imglink', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	return undef unless ($self->img_size);
	
	return '<img src="' . $self->src_url . '" ' .
		'height=' . $self->img_size->{height} . ' ' .
		'width=' . $self->img_size->{width} . ' ' .
	'>';
};

sub fh {
	my $self = shift;
	return $self->Store->fetch_content_fh($self->checksum);
}

sub content {
	my $self = shift;
	return $self->Store->fetch_content($self->checksum);
}

1;
