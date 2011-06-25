package RapidApp::ErrorReport;
use Moose;

use RapidApp::Error;
use Scalar::Util 'reftype';
use RapidApp::Data::DeepMap ':map_fn';
use RapidApp::Debug 'DEBUG';

our $TRIMMER;
our $MAX_DEPTH;

has 'dateTime' => ( is => 'rw', isa => 'DateTime', required => 1, builder => '_build_dateTime' );
sub _build_dateTime {
	my $self= shift;
	my $d= DateTime->from_epoch(epoch => time, time_zone => 'UTC');
	return $d;
}

has 'exception' => ( is => 'rw', required => 1 );

has 'userComment' => ( is => 'rw' );

has 'traces' => ( is => 'rw', isa => 'ArrayRef', required => 1 );

has 'debugInfo' => (
	traits	=> ['Hash'],
	is        => 'ro',
	isa       => 'HashRef',
	default   => sub { {} },
	handles   => { apply_debugInfo => 'set' }
);

sub getTrimmedClone {
	my ($self, $maxDepth)= @_;
	$maxDepth ||= 4;
	$TRIMMER->reset();
	local $MAX_DEPTH= $maxDepth;
	my $ret= $TRIMMER->translate($self);
	$TRIMMER->reset();
	return $ret;
}

$TRIMMER= RapidApp::Data::DeepMap->new(
	defaultMapper => \&fn_trimUnwantedCrap,
	mapperByRef => {
		'HASH'  => \&fn_trimUnwantedCrap,
		'ARRAY' => \&fn_trimUnwantedCrap,
		'REF'   => \&fn_trimUnwantedCrap,
	},
	mapperByISA => {
		'Catalyst' => sub { '$c'; },
		'RapidApp::Module' => \&fn_snub,
		'Catalyst::Component' => \&fn_snub,
		'DBIx::Class::Schema' => \&fn_snub,
		'DBIx::Class::ResultSource' => \&fn_snub,
		'DBIx::Class::ResultSet' => \&fn_snub,
		'DBIx::Class::Storage' => \&fn_snub,
		'DBI' => \&fn_snub,
		'IO::Handle' => \&fn_snub,
		#'RapidApp::Error' => \&RapidApp::Data::DeepMap::fn_translateBlessedContents,
		'RapidApp::ErrorReport' => \&fn_translateBlessedContents,
		'Devel::StackTrace' => \&fn_trimStackTrace,
		'Devel::StackTrace::Frame' => \&fn_translateBlessedContents,
	}
);

sub fn_trimStackTrace {
	my ($trace, $mapper, $type)= @_;
	my $depth= $mapper->currentDepth;
	$mapper->currentDepth(0);
	my $result= &fn_translateBlessedContents($trace, $mapper);
	$mapper->currentDepth($depth);
	return $result;
}

sub fn_trimUnwantedCrap {
	my ($obj, $mapper, $type)= @_;
	$type or return $obj;
	$mapper->currentDepth < $MAX_DEPTH or return fn_snub(@_);
	$type eq 'HASH' and return fn_translateHashContents(@_);
	$type eq 'ARRAY' and return fn_translateArrayContents(@_);
	$type eq 'REF' and return fn_translateRefContents(@_);
	blessed($obj) && $type eq ref $obj
		and return fn_translateBlessedContents(@_);
	return fn_snub(@_);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
