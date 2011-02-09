package RapidApp::FilterableDebug;
use Moose::Role;
use Term::ANSIColor;

requires 'debug';

has 'debugChannels' => ( is => 'ro', required => 1,
	default => sub { RapidApp::FilterableDebug::Channels->new(owner => shift) },
	#trigger => sub { my ($self, $new, $old)= @_; $new->owner($self); $new; },
);

around 'BUILDARGS' => sub {
	my ($orig, $class, @args)= @_;
	my $ret= $class->$orig(@args);
	
	# coersion for 'channels'
	ref $ret eq 'HASH' && ref $ret->{debugChannels} eq 'HASH'
		and $ret->{debugChannels}= RapidApp::FilterableDebug::Channels->new_from_config($ret->{debugChannels});
	
	return $ret;
};

our $AUTOLOAD;
sub AUTOLOAD {
	my $self= shift;
	$AUTOLOAD =~ /.*:debug_([^:]+)/ or die "No method $AUTOLOAD";
	
	my $channelName= $1;
	my $channel= $self->debugChannels->get($channelName);
	if (!defined $channel) {
		warn "No debug channel $channelName";
		return;
	}
	
	return unless $channel->enabled;
	
	my ($ignore, $file, $line)= $channel->showSrcLoc? (caller) : ();
	$self->_filtered_debug_emit($file, $line, $channel->color, @_, Term::ANSIColor::CLEAR);
}

sub _filtered_debug_emit {
	my ($self, $srcFile, $srcLine, @data)= @_;
	
	my $locInfo= '';
	if (defined $srcFile) {
		$srcFile =~ s|^.*lib/||;
		$locInfo = $srcFile . ' line '. $srcLine . "\n";
	}
	
	my $msg= join('', map { $self->_debug_data_to_text($_) } @data );
	$self->debug($locInfo . $msg);
}

sub _debug_data_to_text {
	my ($self, $data)= @_;
	ref $data or return $data;
	ref $data eq 'CODE' and return &$data;
	return Dumper($data);
}

=pod
sub _buildChannelMethods {
	my ($self, @channels)= @_;
	for my $channel (@channels) {
		if ($channel->enabled) {
			my $color= $channel->color;
			my $loc= $channel->showSrcLoc;
			eval "package ".__PACKAGE__."; sub debug_$chanName { _debug_channel_emit(\"$color\", \"$loc\", @_ ); }";
		}
		else {
			eval "package ".__PACKAGE__."; sub debug_$chanName {}";
		}
	}
}
=cut


package RapidApp::FilterableDebug::Channels;
use Moose;

has '_channels' => ( is => 'ro', isa => 'HashRef[RapidApp::FilterableDebug::Channel]', default => sub {{}} );
has 'owner'     => ( is => 'rw' );

sub new_from_config {
	my ($class, $cfg)= @_;
	
	my $self= $class->new();
	
	while (my ($key, $val)= each %$cfg) {
		$self->add($key, $val || {});
	}
	
	return $self;
}

sub add {
	my ($self, $nameOrObj, $cfg)= @_;
	if (!ref $nameOrObj) {
		$cfg ||= { };
		$nameOrObj= RapidApp::FilterableDebug::Channel->new({ %$cfg, name => $nameOrObj });
	}
	$nameOrObj->isa('RapidApp::FilterableDebug::Channel') or die "expected Channel object";
	$self->_channels->{$nameOrObj->name}= $nameOrObj;
}

sub get {
	my ($self, $name)= @_;
	return $self->_channels->{$name};
}

no Moose;
__PACKAGE__->meta->make_immutable;

package RapidApp::FilterableDebug::Channel;
use Moose;

has 'name'       => ( is => 'ro', isa => 'Str', required => 1 );
has 'enabled'    => ( is => 'rw', isa => 'Bool', lazy_build => 1 );
has 'color'      => ( is => 'rw', default => Term::ANSIColor::YELLOW );
has 'showSrcLoc' => ( is => 'rw', default => 1 );

sub _build_enabled {
	my $self= shift;
	return $ENV{'DEBUG_'.uc($self->name)}? 1 : 0;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;