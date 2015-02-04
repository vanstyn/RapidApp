package RapidApp::TableSpec::ColSpec;
use strict;
use Moose;
use Moose::Util::TypeConstraints;

use RapidApp::Include qw(sugar perlutil);

=head1 ColSpec format 'include_colspec'

The include_colspec attribute defines joins and columns to include. It consists 
of a list of "ColSpecs"

The ColSpec format is a string format consisting of consists of 2 parts: an 
optional 'relspec' followed by a 'colspec'. The last dot "." in the string separates
the relspec on the left from the colspec on the right. A string without periods
has no (or an empty '') relspec.

The relspec is a chain of relationship names delimited by dots. These must be exact
relnames in the correct order. These are used to create the base DBIC join attr. For
example, this relspec (to the left of .*):

 object.owner.contact.*
 
Would become this join:

 { object => { owner => 'contact' } }
 
Multple overlapping rels are collapsed in an inteligent manner. For example, this:

 object.owner.contact.*
 object.owner.notes.*
 
Gets collapsed into this join:

 { object => { owner => [ 'contact', 'notes' ] } }
 
The colspec to the right of the last dot "." is a glob pattern match string to identify
which columns of that last relationship to include. Standard simple glob wildcards * ? [ ]
are supported (this is powered by the Text::Glob module. ColSpecs with no relspec apply to
the base table/class. If no base colspecs are defined, '*' is assumed, which will include
all columns of the base table (but not of any related tables). 

Note that this ColSpec:

 object.owner.contact
 
Would join { object => 'owner' } and include one column named 'contact' within the owner table.

This ColSpec, on the other hand:

 object.owner.contact.*
 
Would join { object => { owner => 'contact' } } and include all columns within the contact table.

The ! chacter can exclude instead of include. It can only be at the start of the line, and it will
cause the colspec to exclude columns that match the pattern. For the purposes of joining, ! ColSpecs
are ignored.

=head1 EXAMPLE ColSpecs:

	'name',
	'!id',
	'*',
	'!*',
	'project.*', 
	'user.*',
	'contact.notes.owner.foo*',
	'contact.notes.owner.foo.sd',
	'project.dist1.rsm.object.*_ts',
	'relation.column',
	'owner.*',
	'!owner.*_*',

=cut


use Type::Tiny;
my $TYPE_ColSpecStr = Type::Tiny->new(
  name       => "ColSpecStr",
  constraint => sub {
    /\s+/ and warn "ColSpec '$_' is invalid because it contains whitespace" and return 0;
    /[A-Z]+/ and warn "ColSpec '$_' is invalid because it contains upper case characters" and return 0;
    /([^\#a-z0-9\-\_\.\!\*\?\[\]\{\}\:])/ and warn "ColSpec '$_' contains invalid characters ('$1')." and return 0;
    /^\./ and warn "ColSpec '$_' is invalid: \".\" cannot be the first character" and return 0;
    /\.$/ and warn "ColSpec '$_' is invalid: \".\" cannot be the last character (did you mean '$_*' ?)" and return 0;

    $_ =~ s/^\#//;
      /\#/ and warn "ColSpec '$_' is invalid: # (comment) character may only be supplied at the begining of the string." and return 0;

    $_ =~ s/^\!//;
    /\!/ and warn "ColSpec '$_' is invalid: ! (not) character may only be supplied at the begining of the string." and return 0;

    return 1;
  },
  message => sub { "$_ not a ColSpecStr (see previous warnings)" }
);
sub ColSpecStr { $TYPE_ColSpecStr }

subtype 'ColSpecStr', as 'Str', where { $TYPE_ColSpecStr->constraint->(@_) };

has 'colspecs', is => 'ro', isa => 'ArrayRef[ColSpecStr]', required => 1;
sub all_colspecs { uniq( @{(shift)->colspecs} ) }  
sub add_colspecs { push @{(shift)->colspecs}, @_ }


# Store the orig/init colspec data in 'init_colspecs'
has 'init_colspecs', is => 'ro', required => 1;
around BUILDARGS => sub {
	my $orig = shift;
	my $class = shift;
	my %params = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	$params{init_colspecs} = [ @{$params{colspecs}} ] if (ref($params{colspecs}) eq 'ARRAY');
	return $class->$orig(%params);
};

sub BUILD {
	my $self = shift;
	$self->regen_subspec;
}

after 'expand_colspecs' => sub { (shift)->regen_subspec(@_) };
after 'add_colspecs' => sub { (shift)->regen_subspec(@_) };


sub expand_colspecs {
	my $self = shift;
	my $code = shift;
	
	@{$self->colspecs} = $code->(@{$self->colspecs});
}



sub regen_subspec {
	my $self = shift;
	$self->_clear_rel_order;
	$self->_clear_subspec;
	$self->_clear_subspec_data;
	$self->subspec;
}


has 'rel_order', is => 'ro', lazy => 1, clearer => '_clear_rel_order', default => sub {
	my $self = shift;
	return $self->_subspec_data->{order};
}, isa => 'ArrayRef';
sub all_rel_order   { uniq( @{(shift)->rel_order} ) }  
sub count_rel_order { scalar( (shift)->all_rel_order ) }

has 'subspec', is => 'ro', lazy => 1, clearer => '_clear_subspec', default => sub {
	my $self = shift;
	my $data = $self->_subspec_data->{data};
	return { '' => $self } unless ($self->count_rel_order > 1);
	return { map { $_ => __PACKAGE__->new(colspecs => $data->{$_}) } keys %$data };
}, isa => 'HashRef';
sub get_subspec { (shift)->subspec->{$_[0]} }



has '_subspec_data', is => 'ro', isa => 'HashRef', lazy => 1,  clearer => '_clear_subspec_data',
default => sub {
	my $self = shift;
	
	my @order = ('');
	my %data = ('' => []);
	
	my %end_rels = ( '' => 1 );
	foreach my $spec ($self->all_colspecs) {
		my $pre; { my ($match) = ($spec =~ /^(\!)/); $spec =~ s/^(\!)//; $pre = $match ? $match : ''; }
		
		my @parts = split(/\./,$spec);
		my $rel = shift @parts;
		my $subspec = join('.',@parts);
		unless(@parts > 0) { # <-- if its the base rel
			$subspec = $rel;
			$rel = '';
		}
		
		# end rels that link to colspecs and not just to relspecs 
		# (intermediate rels with no direct columns)
		$end_rels{$rel}++ if (
			not $subspec =~ /\./ and 
			$pre eq ''
		 );
		
		unless(defined $data{$rel}) {
			$data{$rel} = [];
			push @order, $rel;
		}
		
		push @{$data{$rel}}, $pre . $subspec;
	}
	
	# Set the base colspec to '*' if its empty: 
	push @{$data{''}}, '*' unless (@{$data{''}} > 0);
	$end_rels{$_} or push @{$data{$_}}, '!*' for (@order);
	
	return {
		data => \%data,
		order => \@order
	};
};

sub base_colspec {
	my $self = shift;
	return $self->get_subspec('');
}





1;