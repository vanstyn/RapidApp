package RapidApp::Data::DeepMap;
use Exporter 'import';
use Moose;

use Scalar::Util qw(blessed reftype refaddr);

has '_mapperCache'     => ( is => 'rw', isa => 'HashRef', lazy_build => 1 );
has '_translatedCache' => ( is => 'rw', isa => 'HashRef', lazy_build => 1 );

has 'defaultMapper' => ( is => 'rw', isa => 'CodeRef', default => sub { \&fn_passthrough }, trigger => \&_clear_mapperCache );
has '_mapperByRef'  => ( is => 'ro', isa => 'HashRef', default => sub {{}}, init_arg => 'mapperByRef' );
has '_mapperByISA'  => ( is => 'ro', isa => 'HashRef', default => sub {{}}, init_arg => 'mapperByISA' );
has 'blessedMapMethod' => ( is => 'rw', isa => 'Str', default => 'deepMap' );
has 'currentDepth'    => ( is => 'rw', isa => 'Int', default => 0 );

sub _build__mapperCache {
	my $self= shift;
	return {
		HASH  => $self->_mapperByRef->{HASH}  || \&fn_translateHashContents,
		ARRAY => $self->_mapperByRef->{ARRAY} || \&fn_translateArrayContents,
		REF   => $self->_mapperByRef->{REF}   || \&fn_translateRefContents,
	}; # was defaulting it to the _mapperByRef, but might as well just build the content lazily too
}
sub _build__translatedCache {
	{};
}

sub reset {
	my $self= shift;
	$self->_clear_mapperCache;
	$self->_clear_translatedCache;
	$self->currentDepth(0);
}

sub applyMapperByRef {
	my $self= shift;
	my $args= ref $_[0] eq 'HASH'? $_[0] : { @_ };
	$self->_clear_mapperCache;
	while (my ($key, $val)= each %$args) {
		$self->mapperByRef->{$key}= $val;
	}
}

sub applyMapperByISA {
	my $self= shift;
	my $args= ref $_[0] eq 'HASH'? $_[0] : { @_ };
	$self->_clear_mapperCache;
	while (my ($key, $val)= each %$args) {
		$self->mapperByISA->{$key}= $val;
	}
}

 sub _trace {
	 my @caller= caller(1);
	 print STDERR $caller[3].'( '.join (', ', @_)." )\n";
 }

sub translate {
	#_trace(@_);
	my ($self, $obj)= @_;
	my $r= ref $obj;
	!$r
		and return $self->defaultMapper->($obj, $self, '');
	
	# use cached, if possible
	return $self->_translatedCache->{refaddr $obj} if exists $self->_translatedCache->{refaddr $obj};
	
	my $mapperFn= $self->_mapperCache->{$r} || $self->_getMapperFor($r);
	return ($self->_translatedCache->{refaddr $obj}= &$mapperFn($obj, $self, $r));
}

my @map_functions= qw(
	fn_passthrough fn_snub fn_prune
	fn_translateContents
	fn_translateHashContents
	fn_translateArrayContents
	fn_translateRefContents
	fn_translateBlessedContents );
our @EXPORT_OK= @map_functions;
our %EXPORT_TAGS= (map_fn => [ @map_functions ] );

sub fn_passthrough {#_trace(@_);
	$_[0]
}
sub fn_snub {
	my $obj= shift;
	!defined $obj and return '[undef]';
	ref $obj and return '['.ref($obj).'@'.refaddr($obj).']';
	length($obj) > 20 and return "'".substr($obj, 0, 17)."'...";
	return "'$obj'";
}
sub fn_prune {#_trace(@_);
	undef
}

sub fn_translateContents {
	#_trace(@_);
	my ($obj, $mapper, $type)= @_;
	ref $obj or return $obj;
	blessed($obj) and return &fn_translateBlessedContents(@_);
	ref $obj eq 'HASH'   and return &fn_translateHashContents(@_);
	ref $obj eq 'ARRAY'  and return &fn_translateArrayContents(@_);
	ref $obj eq 'REF' || ref $obj eq 'SCALAR' and return &fn_translateRefContents(@_);
	return $obj;
}

sub fn_translateHashContents {
	#_trace(@_);
	my ($obj, $mapper, $type)= @_;
	my $result= {};
	$mapper->_translatedCache->{refaddr $obj}= $result;
	my @content= %$obj;
	my $depth= $mapper->currentDepth;
	$mapper->currentDepth($depth+1);
	for (my $i=$#content; $i > 0; $i-= 2) {
		$content[$i]= $mapper->translate($content[$i]);
	}
	$mapper->currentDepth($depth);
	%$result= @content;
	return $result;
}

sub fn_translateArrayContents {
	#_trace(@_);
	my ($obj, $mapper, $type)= @_;
	my @content= @$obj;
	$mapper->_translatedCache->{refaddr $obj}= \@content;
	my $depth= $mapper->currentDepth;
	$mapper->currentDepth($depth+1);
	for (my $i=$#content; $i >= 0; $i--) {
		$content[$i]= $mapper->translate($content[$i]);
	}
	$mapper->currentDepth($depth);
	return \@content;
}

sub fn_translateRefContents {
	#_trace(@_);
	my ($obj, $mapper, $type)= @_;
	$mapper->_translatedCache->{refaddr $obj}= \$obj;
	$obj= $mapper->translate($$obj);
	return \$obj;
}

sub fn_translateBlessedContents {
	#_trace(@_);
	my ($obj, $mapper, $type)= @_;
	my $r= reftype $obj;
	return fn_passthrough(@_) if (defined $type && $type eq $r); # prevent infinite loops if we become the mapper for a non-blessed type.
	my $mapperFn= $mapper->_mapperCache->{$r} || $mapper->_getMapperFor($r);
	my $newObj= &$mapperFn($obj, $mapper, $r);
	return bless $newObj, ref($obj) if (ref $newObj && !blessed $newObj);
	return $newObj;
}

sub _getMapperFor {
	#_trace(@_);
	my ($self, $type)= @_;
	
	# is there a 'ref' rule for it?
	my $mapperFn= $self->_mapperByRef->{$type};
	
	# check for an ISA rule.  Note that it doesn't hurt to run "isa" on non-existant packages like HASH or ARRAY.
	if (!defined $mapperFn) {
		for my $key (keys %{$self->_mapperByISA}) {
			#print STDERR "$type->isa($key): ".$type->isa($key)." (".$self->_mapperByISA->{$key}.")\n";
			if ($type->isa($key)) {
				$mapperFn= $self->_mapperByISA->{$key};
				last;
			}
		}
	}
	
	# check for a mapper method.  Note that it doesn't hurt to run "can" on non-existant packages like HASH or ARRAY.
	$mapperFn ||= $type->can($self->blessedMapMethod);
	
	# else, use the default
	$mapperFn ||= $self->defaultMapper;
	
	# cache the result
	$self->_mapperCache->{$type}= $mapperFn;
	
	return $mapperFn;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;