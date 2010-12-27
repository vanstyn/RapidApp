package RapidApp::Data::DeepMap;

use Moose;

use Scalar::Util qw(blessed reftype);

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
	_trace(@_);
	my ($self, $obj)= @_;
	return $self->_translatedCache->{$obj} if defined $obj && exists $self->_translatedCache->{$obj};
	return $self->defaultMapper->($obj, $self, '') unless ref $obj;
	
	my $r= ref $obj;
	my $mapperFn= $self->_mapperCache->{$r} || $self->_getMapperFor($r);
	return ($self->_translatedCache->{$obj}= &$mapperFn($obj, $self, $r));
}

sub fn_passthrough {#_trace(@_);
	$_[0]
}
sub fn_prune {#_trace(@_);
	undef
}

sub fn_translateContents {
	#_trace(@_);
	my ($obj, $mapper)= @_;
	ref $obj or return $obj;
	blessed($obj) and return &fn_translateBlessedContents(@_);
	ref $obj eq 'HASH'   and return &fn_translateHashContents(@_);
	ref $obj eq 'ARRAY'  and return &fn_translateArrayContents(@_);
	ref $obj eq 'REF' || ref $obj eq 'SCALAR' and return &fn_translateRefContents(@_);
	return $obj;
}

sub fn_translateHashContents {
	#_trace(@_);
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
	#_trace(@_);
	my ($obj, $mapper)= @_;
	my @content= @$obj;
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
	my ($obj, $mapper)= @_;
	$obj= $mapper->translate($$obj);
	return \$obj;
}

sub fn_translateBlessedContents {
	#_trace(@_);
	my ($obj, $mapper)= @_;
	my $r= reftype $obj;
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