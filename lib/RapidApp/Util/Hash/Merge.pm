package RapidApp::Util::Hash::Merge;

# --- 2018-08-06 by HV ---
# This is a copy of Hash::Merge v2.00, since later versions do not behave as expected.
# This is a temporary measure. If at some point I (or someone) has time to figure out 
# what to do to get the real Hash::Merge to play nicely, I'd be happy to unfactor this.
# In the meantime, its too important for this stuff to work properly.
# -- See https://github.com/vanstyn/RapidApp/issues/177 and possibly #155
# ---

use strict;
use warnings;
use Carp;

use base 'Exporter';
use vars qw($VERSION @ISA @EXPORT_OK %EXPORT_TAGS $context);

my ( $GLOBAL, $clone );

#$VERSION     = '0.200';
@EXPORT_OK   = qw( merge _hashify _merge_hashes );
%EXPORT_TAGS = ( 'custom' => [qw( _hashify _merge_hashes )] );

$GLOBAL = {};
bless $GLOBAL, __PACKAGE__;
$context = $GLOBAL;    # $context is a variable for merge and _merge_hashes. used by functions to respect calling context

$GLOBAL->{'behaviors'} = {
    'LEFT_PRECEDENT' => {
        'SCALAR' => {
            'SCALAR' => sub { $_[0] },
            'ARRAY'  => sub { $_[0] },
            'HASH'   => sub { $_[0] },
        },
        'ARRAY' => {
            'SCALAR' => sub { [ @{ $_[0] }, $_[1] ] },
            'ARRAY'  => sub { [ @{ $_[0] }, @{ $_[1] } ] },
            'HASH'   => sub { [ @{ $_[0] }, values %{ $_[1] } ] },
        },
        'HASH' => {
            'SCALAR' => sub { $_[0] },
            'ARRAY'  => sub { $_[0] },
            'HASH'   => sub { _merge_hashes( $_[0], $_[1] ) },
        },
    },

    'RIGHT_PRECEDENT' => {
        'SCALAR' => {
            'SCALAR' => sub { $_[1] },
            'ARRAY'  => sub { [ $_[0], @{ $_[1] } ] },
            'HASH'   => sub { $_[1] },
        },
        'ARRAY' => {
            'SCALAR' => sub { $_[1] },
            'ARRAY'  => sub { [ @{ $_[0] }, @{ $_[1] } ] },
            'HASH'   => sub { $_[1] },
        },
        'HASH' => {
            'SCALAR' => sub { $_[1] },
            'ARRAY'  => sub { [ values %{ $_[0] }, @{ $_[1] } ] },
            'HASH'   => sub { _merge_hashes( $_[0], $_[1] ) },
        },
    },

    'STORAGE_PRECEDENT' => {
        'SCALAR' => {
            'SCALAR' => sub { $_[0] },
            'ARRAY'  => sub { [ $_[0], @{ $_[1] } ] },
            'HASH'   => sub { $_[1] },
        },
        'ARRAY' => {
            'SCALAR' => sub { [ @{ $_[0] }, $_[1] ] },
            'ARRAY'  => sub { [ @{ $_[0] }, @{ $_[1] } ] },
            'HASH'   => sub { $_[1] },
        },
        'HASH' => {
            'SCALAR' => sub { $_[0] },
            'ARRAY'  => sub { $_[0] },
            'HASH'   => sub { _merge_hashes( $_[0], $_[1] ) },
        },
    },

    'RETAINMENT_PRECEDENT' => {
        'SCALAR' => {
            'SCALAR' => sub { [ $_[0],                          $_[1] ] },
            'ARRAY'  => sub { [ $_[0],                          @{ $_[1] } ] },
            'HASH'   => sub { _merge_hashes( _hashify( $_[0] ), $_[1] ) },
        },
        'ARRAY' => {
            'SCALAR' => sub { [ @{ $_[0] },                     $_[1] ] },
            'ARRAY'  => sub { [ @{ $_[0] },                     @{ $_[1] } ] },
            'HASH'   => sub { _merge_hashes( _hashify( $_[0] ), $_[1] ) },
        },
        'HASH' => {
            'SCALAR' => sub { _merge_hashes( $_[0], _hashify( $_[1] ) ) },
            'ARRAY'  => sub { _merge_hashes( $_[0], _hashify( $_[1] ) ) },
            'HASH'   => sub { _merge_hashes( $_[0], $_[1] ) },
        },
    },
};

$GLOBAL->{'behavior'} = 'LEFT_PRECEDENT';
$GLOBAL->{'matrix'}   = $GLOBAL->{behaviors}{ $GLOBAL->{'behavior'} };
$GLOBAL->{'clone'}    = 1;

sub _get_obj {
    if ( my $type = ref $_[0] ) {
        return shift() if $type eq __PACKAGE__ || eval { $_[0]->isa(__PACKAGE__) };
    }

    return $context;
}

sub new {
    my $pkg = shift;
    $pkg = ref $pkg || $pkg;
    my $beh = shift || $context->{'behavior'};

    croak "Behavior '$beh' does not exist" if !exists $context->{'behaviors'}{$beh};

    return bless {
        'behavior' => $beh,
        'matrix'   => $context->{'behaviors'}{$beh},
    }, $pkg;
}

sub set_behavior {
    my $self  = &_get_obj;    # '&' + no args modifies current @_
    my $value = uc(shift);
    if ( !exists $self->{'behaviors'}{$value} and !exists $GLOBAL->{'behaviors'}{$value} ) {
        carp 'Behavior must be one of : ' . join( ', ', keys %{ $self->{'behaviors'} }, keys %{ $GLOBAL->{'behaviors'}{$value} } );
        return;
    }
    my $oldvalue = $self->{'behavior'};
    $self->{'behavior'} = $value;
    $self->{'matrix'} = $self->{'behaviors'}{$value} || $GLOBAL->{'behaviors'}{$value};
    return $oldvalue;         # Use classic POSIX pattern for get/set: set returns previous value
}

sub get_behavior {
    my $self = &_get_obj;     # '&' + no args modifies current @_
    return $self->{'behavior'};
}

sub specify_behavior {
    my $self = &_get_obj;     # '&' + no args modifies current @_
    my ( $matrix, $name ) = @_;
    $name ||= 'user defined';
    if ( exists $self->{'behaviors'}{$name} ) {
        carp "Behavior '$name' was already defined. Please take another name";
        return;
    }

    my @required = qw( SCALAR ARRAY HASH );

    foreach my $left (@required) {
        foreach my $right (@required) {
            if ( !exists $matrix->{$left}->{$right} ) {
                carp "Behavior does not specify action for '$left' merging with '$right'";
                return;
            }
        }
    }

    $self->{'behavior'} = $name;
    $self->{'behaviors'}{$name} = $self->{'matrix'} = $matrix;
}

sub set_clone_behavior {
    my $self     = &_get_obj;          # '&' + no args modifies current @_
    my $oldvalue = $self->{'clone'};
    $self->{'clone'} = shift() ? 1 : 0;
    return $oldvalue;
}

sub get_clone_behavior {
    my $self = &_get_obj;              # '&' + no args modifies current @_
    return $self->{'clone'};
}

sub merge {
    my $self = &_get_obj;              # '&' + no args modifies current @_

    my ( $left, $right ) = @_;

    # For the general use of this module, we want to create duplicates
    # of all data that is merged.  This behavior can be shut off, but
    # can create havoc if references are used heavily.

    my $lefttype =
        ref $left eq 'HASH'  ? 'HASH'
      : ref $left eq 'ARRAY' ? 'ARRAY'
      :                        'SCALAR';

    my $righttype =
        ref $right eq 'HASH'  ? 'HASH'
      : ref $right eq 'ARRAY' ? 'ARRAY'
      :                         'SCALAR';

    if ( $self->{'clone'} ) {
        $left  = _my_clone( $left,  1 );
        $right = _my_clone( $right, 1 );
    }

    local $context = $self;
    return $self->{'matrix'}->{$lefttype}{$righttype}->( $left, $right );
}

# This does a straight merge of hashes, delegating the merge-specific
# work to 'merge'

sub _merge_hashes {
    my $self = &_get_obj;    # '&' + no args modifies current @_

    my ( $left, $right ) = ( shift, shift );
    if ( ref $left ne 'HASH' || ref $right ne 'HASH' ) {
        carp 'Arguments for _merge_hashes must be hash references';
        return;
    }

    my %newhash;
    foreach my $leftkey ( keys %$left ) {
        if ( exists $right->{$leftkey} ) {
            $newhash{$leftkey} = $self->merge( $left->{$leftkey}, $right->{$leftkey} );
        }
        else {
            $newhash{$leftkey} = $self->{clone} ? $self->_my_clone( $left->{$leftkey} ) : $left->{$leftkey};
        }
    }

    foreach my $rightkey ( keys %$right ) {
        if ( !exists $left->{$rightkey} ) {
            $newhash{$rightkey} = $self->{clone} ? $self->_my_clone( $right->{$rightkey} ) : $right->{$rightkey};
        }
    }

    return \%newhash;
}

# Given a scalar or an array, creates a new hash where for each item in
# the passed scalar or array, the key is equal to the value.  Returns
# this new hash

sub _hashify {
    my $self = &_get_obj;    # '&' + no args modifies current @_
    my $arg  = shift;
    if ( ref $arg eq 'HASH' ) {
        carp 'Arguement for _hashify must not be a HASH ref';
        return;
    }

    my %newhash;
    if ( ref $arg eq 'ARRAY' ) {
        foreach my $item (@$arg) {
            my $suffix = 2;
            my $name   = $item;
            while ( exists $newhash{$name} ) {
                $name = $item . $suffix++;
            }
            $newhash{$name} = $item;
        }
    }
    else {
        $newhash{$arg} = $arg;
    }
    return \%newhash;
}

# This adds some checks to the clone process, to deal with problems that
# the current distro of ActiveState perl has (specifically, it uses 0.09
# of Clone, which does not support the cloning of scalars).  This simply
# wraps around clone as to prevent a scalar from being cloned via a
# Clone 0.09 process.  This might mean that CODEREFs and anything else
# not a HASH or ARRAY won't be cloned.

# $clone is global, which should point to coderef

sub _my_clone {
    my $self = &_get_obj;    # '&' + no args modifies current @_
    my ( $arg, $depth ) = @_;

    if ( $self->{clone} && !$clone ) {
        if ( eval { require Clone; 1 } ) {
            $clone = sub {
                if (   !( $Clone::VERSION || 0 ) > 0.09
                    && ref $_[0] ne 'HASH'
                    && ref $_[0] ne 'ARRAY' ) {
                    my $var = shift;    # Forced clone
                    return $var;
                }
                Clone::clone( shift, $depth );
            };
        }
        elsif ( eval { require Storable; 1 } ) {
            $clone = sub {
                my $var = shift;        # Forced clone
                return $var if !ref($var);
                Storable::dclone($var);
            };
        }
        elsif ( eval { require Clone::PP; 1 } ) {
            $clone = sub {
                my $var = shift;        # Forced clone
                return $var if !ref($var);
                Clone::PP::clone( $var, $depth );
            };
        }
        else {
            croak "Can't load Clone, Storable, or Clone::PP for cloning purpose";
        }
    }

    if ( $self->{'clone'} ) {
        return $clone->($arg);
    }
    else {
        return $arg;
    }
}

1;

__END__

=head1 NAME

RappidApp::Util::Hash::Merge - Merges arbitrarily deep hashes into a single hash

=head1 SYNOPSIS

    use RappidApp::Util:Hash::Merge qw( merge );
    my %a = ( 
		'foo'    => 1,
	    'bar'    => [ qw( a b e ) ],
	    'querty' => { 'bob' => 'alice' },
	);
    my %b = ( 
		'foo'     => 2, 
		'bar'    => [ qw(c d) ],
		'querty' => { 'ted' => 'margeret' }, 
	);

    my %c = %{ merge( \%a, \%b ) };

    RappidApp::Util:Hash::Merge::set_behavior( 'RIGHT_PRECEDENT' );

    # This is the same as above

	RappidApp::Util:Hash::Merge::specify_behavior(
	    {
			'SCALAR' => {
				'SCALAR' => sub { $_[1] },
				'ARRAY'  => sub { [ $_[0], @{$_[1]} ] },
				'HASH'   => sub { $_[1] },
			},
			'ARRAY => {
				'SCALAR' => sub { $_[1] },
				'ARRAY'  => sub { [ @{$_[0]}, @{$_[1]} ] },
				'HASH'   => sub { $_[1] }, 
			},
			'HASH' => {
				'SCALAR' => sub { $_[1] },
				'ARRAY'  => sub { [ values %{$_[0]}, @{$_[1]} ] },
				'HASH'   => sub { RappidApp::Util:Hash::Merge::_merge_hashes( $_[0], $_[1] ) }, 
			},
		}, 
		'My Behavior', 
	);
	
	# Also there is OO interface.
	
	my $merge = RappidApp::Util:Hash::Merge->new( 'LEFT_PRECEDENT' );
	my %c = %{ $merge->merge( \%a, \%b ) };
	
	# All behavioral changes (e.g. $merge->set_behavior(...)), called on an object remain specific to that object
	# The legacy "Global Setting" behavior is respected only when new called as a non-OO function.

=head1 DESCRIPTION

This is a copy of L<Hash::Merge> at version 2.00.

See https://metacpan.org/pod/release/REHSACK/Hash-Merge-0.200/lib/Hash/Merge.pm

Please don't use this as it may be removed at any time.

=head1 AUTHOR

Original author Michael K. Neylon E<lt>mneylon-pm@masemware.comE<gt>

Trivial modifications by Henry Van Styn for L<RapidApp>

See https://github.com/vanstyn/RapidApp/issues/177 for why this copy was created.

=head1 COPYRIGHT

Copyright (c) 2001,2002 Michael K. Neylon. All rights reserved.

This library is free software.  You can redistribute it and/or modify it 
under the same terms as Perl itself.

=cut
