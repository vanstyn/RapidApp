package RapidApp::FilterableDebug;
use Moose::Role;
use Term::ANSIColor;

requires 'debug';

has '_debugChannels' => (
	is => 'ro',
	isa => 'HashRef[RapidApp::FilterableDebug::Channel]',
	traits => ['Hash'],
	handles => { getDebugChannels => 'get', debugChannels => 'values' },
	required => 1, default => sub {{}}, init_arg => 'debugChannels',
	# set owner for all channels
	trigger => sub { my ($self, $new, $old)= @_; $_->_owner($self) for (values %$new); },
);

sub applyDebugChannels {
	my ($self, @args)= @_;
	my $cfg= ref $args[0] eq 'HASH'? $args[0] : { @args };
	if (keys(%$cfg)) {
		# for each debug channel definition, either create the channel or alter it
		while (my ($key, $chCfg)= each %$cfg) {
			$chCfg ||= {}; # undef is ok; we just set defaults if the channel doesn't exist or ignore otherwise.
			if (defined $self->_debugChannels->{$key}) {
				$self->_debugChannels->{$key}->applyConfig($chCfg);
			}
			else {
				my $ch= RapidApp::FilterableDebug::Channel->new({ %$chCfg, name => $key });
				$ch->_owner($self);
				$self->_debugChannels->{$key}= $ch;
				# TODO: inline the debug function here
			}
		}
	}
}

our $AUTOLOAD;
sub AUTOLOAD {
	my $self= shift;
	$AUTOLOAD =~ /.*:debug_([^:]+)/ or die "No method $AUTOLOAD";
	
	my $channelName= $1;
	my $channel= $self->getDebugChannels($channelName);
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


package RapidApp::FilterableDebug::Channel;
use Moose;

has 'name'       => ( is => 'ro', isa => 'Str', required => 1 );
has 'enabled'    => ( is => 'rw', isa => 'Bool', lazy_build => 1 );
has 'color'      => ( is => 'rw', default => Term::ANSIColor::YELLOW );
has 'showSrcLoc' => ( is => 'rw', default => 1 );
has '_owner'     => ( is => 'rw', weak_ref => 1 );

sub _build_enabled {
	my $self= shift;
	return $ENV{'DEBUG_'.uc($self->name)}? 1 : 0;
}

sub applyConfig {
	my ($self, @args)= @_;
	my $cfg= ref $args[0] eq 'HASH'? $args[0] : { @args };
	scalar(keys(%$cfg)) or return;
	
	while (my ($key, $val)= each %$cfg) {
		$self->$key($val);
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;