package RapidApp::Log;

use Moose;
# do not extend Catalyst::Log, because that one has funny BUILDARGS overrides

use RapidApp::Include 'sugar', 'perlutil';

has '_log' => (
	is => 'ro',
	init_arg => 'origLog',
	handles => [ qw( fatal is_fatal error is_error warn is_warn info is_info debug is_debug ) ],
);

with 'RapidApp::FilterableDebug';

sub BUILD {
	my $self= shift;
	$self->applyDebugChannels(
		'controller'    => { color => MAGENTA,  },
		'dbiclink'      => { color => MAGENTA, showSrcLoc => 0 },
		'notifications' => { color => YELLOW,   },
		'web1render'    => { color => CYAN,     },
	);
}

# The neat thing we're doing here is making an object which can be added to a debug_*() statement
#    and will flush the log, but only if that debug channel was enabled.  This way we don't flush if the
#   debug channel wasn't enabled, and we don't need an awkward "if" statement.
# This closure gets generated once per log instance (i.e. once overall) so there's very little
#   performance hit.
has 'FLUSH' => ( is => 'ro', isa => 'CodeRef', lazy_build => 1 );
sub _build_FLUSH {
	my $self= shift;
	sub { $self->flush; '' }
}

sub abort {
	my $self= shift;
	if (my $code= $self->_log->can("abort")) {
		$self->_log->$code(@_);
	}
}

sub flush {
	(shift)->_flush(@_);
}

sub _flush {
	my $self= shift;
	if (my $code= $self->_log->can("_flush")) {
		$self->_log->$code(@_);
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;