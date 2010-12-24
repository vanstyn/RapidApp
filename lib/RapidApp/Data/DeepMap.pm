package RapidApp::Data::DeepMap;

use Moose;

use Scalar::Util qw(blessed reftype);

has '_mapperCache'     => ( is => 'rw', isa => 'HashRef', lazy_build => 1 );
has '_translatedCache' => ( is => 'rw', isa => 'HashRef', lazy_build => 1 );

has 'defaultMapper' => ( is => 'rw', isa => 'CodeRef', default => \&passthrough, trigger => \&_clear_mapperCache );
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

sub translate {
	my ($self, $obj)= @_;
	return $obj unless ref $obj;
	return $self->_translatedCache->{$obj} if exists $self->_translatedCache->{$obj};
	my $mapperFn= $self->_mapperCache->{ref $obj} || $self->_getMapperFor(ref $obj);
	return ($self->_translatedCache->{$obj}= &$mapperFn($obj, $self));
}

sub fn_passthrough { $_[0]; }
sub fn_prune { undef; }

sub fn_translateContents {
	my ($obj, $mapper)= @_;
	ref $obj or return $obj;
	blessed($obj) and return &fn_deepTranslateBlessed(@_);
	ref $obj eq 'HASH'   and return &fn_deepTranslateHash(@_);
	ref $obj eq 'ARRAY'  and return &fn_deepTranslateArray(@_);
	ref $obj eq 'REF' || ref $obj eq 'SCALAR' and return &fn_deepTranslateRef(@_);
	return $obj;
}

sub fn_translateHashContents {
	my ($obj, $mapper)= @_;
	my @content= %$obj;
	my $depth= $mapper->currentDepth;
	$mapper->currentDepth($depth+1);
	for (my $i=$#content; $i > 0; $i-= 2) {
		$content[$i]= $mapper->translate($content[$i]);
	}
	$mapper->currentDepth($depth);
	return { @content };
}

sub fn_translateArrayContents {
	my ($obj, $mapper)= @_;
	my @content= @$obj;
	my $depth= $mapper->currentDepth;
	$mapper->currentDepth($depth+1);
	for (my $i=$#content; $i > 0; $i-= 2) {
		$content[$i]= $mapper->translate($content[$i]);
	}
	$mapper->currentDepth($depth);
	return \@content;
}

sub fn_translateRefContents {
	my ($obj, $mapper)= @_;
	$obj= $mapper->translate($$obj);
	return \$obj;
}

sub fn_translateBlessedContents {
	my ($obj, $mapper)= @_;
	my $mapperFn= $mapper->_mapperCache->{reftype $obj} || $mapper->_getMapperFor(reftype $obj);
	my $newObj= &$mapperFn(@_);
	return bless $newObj, ref($obj) if (ref $newObj && !blessed $newObj);
	return $newObj;
}

sub _getMapperFor {
	my ($self, $type)= @_;
	
	# is there a 'ref' rule for it?
	my $mapperFn= $self->_mapperByRef->{$type};
	
	# check for an ISA rule.  Note that it doesn't hurt to run "isa" on non-existant packages like HASH or ARRAY.
	for my $key (keys %{$self->_mapperByISA}) {
		if ($type->isa($key)) {
			$mapperFn= $self->_mapperByISA->{$key};
			last;
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