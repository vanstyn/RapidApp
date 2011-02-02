package RapidApp::ErrorReport;
use Moose;

use RapidApp::Error;

our $TRIMMER;

has 'dateTime' => ( is => 'rw', isa => 'DateTime', required => 1, lazy_build => 1 );
sub _build_dateTime {
	my $self= shift;
	my $d= DateTime->from_epoch(epoch => time, time_zone => 'UTC');
	return $d;
}

has 'exception' => ( is => 'rw', required => 1 );

has 'traces' => ( is => 'rw', isa => 'ArrayRef', required => 1 );

has 'debugInfo' => ( is => 'rw', default => undef );

sub getTrimmedClone {
	my ($self, $maxDepth)= @_;
	$TRIMMER->reset();
	local $MAX_DEPTH= $maxDepth;
	my $ret= $TRIMMER->translate($self);
	$TRIMMER->reset();
	return $ret;
}

our $MAX_DEPTH= 3;

$TRIMMER= RapidApp::Data::DeepMap->new(
	defaultMapper => \&fn_trimUnwantedCrap,
	mapperByRef => {
		'HASH'  => \&fn_trimUnwantedCrap,
		'ARRAY' => \&fn_trimUnwantedCrap,
		'REF'   => \&fn_trimUnwantedCrap,
	},
	mapperByISA => {
		'Catalyst' => sub { '$c'; },
		'RapidApp::Module' => \&fn_snubBlessed,
		'Catalyst::Component' => \&fn_snubBlessed,
		'IO::Handle' => \&fn_snubBlessed,
		'RapidApp::Error' => \&RapidApp::Data::DeepMap::fn_translateBlessedContents,
		'RapidApp::ErrorReport' => \&RapidApp::Data::DeepMap::fn_translateBlessedContents,
		'Devel::StackTrace' => \&fn_trimStackTrace,
		'Devel::StackTrace::Frame' => \&RapidApp::Data::DeepMap::fn_translateBlessedContents,
	}
);

sub fn_trimStackTrace {
	my ($trace, $mapper, $type)= @_;
	my $depth= $mapper->currentDepth;
	$mapper->currentDepth(0);
	my $result= &RapidApp::Data::DeepMap::fn_translateBlessedContents($trace, $mapper);
	$mapper->currentDepth($depth);
	return $result;
}

sub fn_trimUnwantedCrap {
	my ($obj, $mapper, $type)= @_;
	$type or return $obj;
	$mapper->currentDepth < $MAX_DEPTH or return "[$obj]";
	$type= reftype($obj) if blessed($obj);
	$type eq 'HASH' and return RapidApp::Data::DeepMap::fn_translateHashContents(@_);
	$type eq 'ARRAY' and return RapidApp::Data::DeepMap::fn_translateArrayContents(@_);
	$type eq 'REF' and return RapidApp::Data::DeepMap::fn_translateRefContents(@_);
	return "[$obj]";
}

sub fn_snubBlessed {
	my ($obj, $mapper, $type)= @_;
	return "[$type]";
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
