package RapidApp::Debug;
use Moose;
use Term::ANSIColor;
use Data::Dumper;
use RapidApp::ScopedGlobals;
use IO::Handle;

has 'dest'     => ( is => 'rw', default => undef );
has 'channels' => ( is => 'ro', isa => 'HashRef[RapidApp::Debug::Channel]', default => sub {{}} );

sub applyChannelConfig {
	my ($self, @args)= @_;
	
	# convert class context to object context
	ref $self or return (shift)->default_instance->applyChannelConfig(@_);
	
	my $cfg= ref $args[0] eq 'HASH'? $args[0] : { @args };
	if (keys(%$cfg)) {
		# for each debug channel definition, either create the channel or alter it
		while (my ($key, $chCfg)= each %$cfg) {
			$chCfg ||= {}; # undef is ok; we just set defaults if the channel doesn't exist or ignore otherwise.
			if (defined $self->channels->{$key}) {
				$self->channels->{$key}->applyConfig($chCfg)
			} else {
				$self->_create_channel($key, $chCfg);
			}
		}
	}
}

sub write {
	my ($self, $chanName, @args)= @_;
	return unless (ref $chanName? $self->any_channel_enabled($chanName) : $ENV{'DEBUG_'.uc($chanName)});
	
	goto &_write; # we don't want to mess up 'caller'
}

sub _write {
	my ($self, $chanName, @args)= @_;
	my $ch= $self->channels->{$chanName} || $self->_autocreate_channel($chanName);
	my $color= $ch->color;
	my $locInfo= '';
	if ($ch->showSrcLoc) {
		my ($ignore, $srcFile, $srcLine)= caller;
		$srcFile =~ s|^.*lib/||;
		$locInfo = $srcFile . ' line '. $srcLine . "\n";
	}
	my @argText= map { $self->_debug_data_to_text($_) } @args;
	my $msg= join(' ', $locInfo, $color, @argText, Term::ANSIColor::CLEAR() );
	
	my $dest= $ch->dest || $self->dest || RapidApp::ScopedGlobals->get('log') || _getStderrHandle();
	
	my $code;
	($code= $dest->can('debug'))? $dest->$code($msg) : $dest->print($msg."\n");
	
	if ($ch->autoFlush) {
		($code= $dest->can('flush') || $dest->can('_flush')) && $dest->$code();
	}
}

sub _getStderrHandle {
	my $io= IO::Handle->new;
	$io->fdopen(fileno(STDERR), "w");
	return $io;
}

sub _autocreate_channel {
	my ($self, $name)= @_;
	my $app= RapidApp::ScopedGlobals->get('catalystClass');
	my $app_cfg= $app && $app->config->{Debug};
	my $cfg= (defined $app_cfg && defined $app_cfg->{channels} && $app_cfg->{channels}{$name}) || {};
	return $self->_create_channel($name, $cfg);
}

sub _create_channel {
	my ($self, $name, $chanCfg)= @_;
	return $self->channels->{$name}= RapidApp::Debug::Channel->new({ %$chanCfg, name => $name, _owner => $self });
}

sub _debug_data_to_text {
	my ($self, $data)= @_;
	defined $data or return '<undef>';
	ref $data or return $data;
	ref $data eq 'CODE' and return &$data;
	my $dump= Data::Dumper->new([$data], [''])->Indent(1)->Maxdepth(5)->Dump;
	$dump= substr($dump, 4, length($dump)-6); # trim off "$ = " and ";\n"
	length($dump) < 80 # inline short hashes
		and $dump =~ s/\n\s*/ /g;
	length($dump) > 2000 # truncate long hashes
		and $dump= substr($dump, 0, 2000)."\n[...]\n";
	return $dump;
}

no Moose;
__PACKAGE__->meta->make_immutable;

# ----------------------------------------------------------------------------
# Globally available methods
#

my $INSTANCE;
sub default_instance {
	my $class= shift;
	return $INSTANCE ||= $class->new();
}

sub global_write {
	my $class= shift;
	my ($chanName, @args)= @_;
	return unless (ref $chanName? $class->any_channel_enabled($chanName) : $ENV{'DEBUG_'.uc($chanName)});
	
	my $self= RapidApp::ScopedGlobals->get("Debug") || $class->default_instance;
	unshift @_, $self;
	goto &_write; # we don't want to mess up 'caller'
}

sub any_channel_enabled {
	my ($class, $chanList)= @_;
	for (my $i=0; $i<scalar(@$chanList); $i++) {
		my $lev= $ENV{'DEBUG_'.$chanList->[$i]};
		return 1 if defined $lev && $lev >= $chanList->[$i+1];
	}
	return 0;
}

use Exporter qw( import );
our @EXPORT_OK= 'DEBUG';

sub DEBUG {
	unshift @_, 'RapidApp::Debug';
	goto &RapidApp::Debug::global_write; # we don't want to mess up 'caller'
}


# ----------------------------------------------------------------------------
# Channel object
#
package RapidApp::Debug::Channel;
use Moose;

has '_owner'     => ( is => 'rw', weak_ref => 1, required => 1 );
has 'name'       => ( is => 'ro', isa => 'Str', required => 1 );
has 'color'      => ( is => 'rw', default => Term::ANSIColor::YELLOW() );
has 'dest'       => ( is => 'rw' ); # log object or file handle
has 'showSrcLoc' => ( is => 'rw', default => 1 );
has 'autoFlush'  => ( is => 'rw', default => 0 );

sub enabled {
	my ($self, $newVal)= @_;
	defined $newVal
		and return $ENV{'DEBUG_'.uc($self->name)}= $newVal;
	return $ENV{'DEBUG_'.uc($self->name)};
}

sub applyConfig {
	my ($self, @args)= @_;
	my $cfg= ref $args[0] eq 'HASH'? $args[0] : { @args };
	scalar(keys(%$cfg)) or return;
	
	while (my ($key, $val)= each %$cfg) {
		$self->$key($val);
	}
	1;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;