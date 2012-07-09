package RapidApp::DBIC::ResultSet::BaseRs;
require base; base->import( 'DBIx::Class::ResultSet');

use RapidApp::Include qw(sugar perlutil);
use Clone qw(clone);

# This ResultSet class is simple and elegant. It extends the standard
# built-in ResultSet class adding the ability to define an optional
# 'base_rs' method
#
# This works with the chained resultset design of DBIC. Each call to
# search_rs actually creates a new object based on the object it was
# called from. Here we set custom attributes that will be passed 
# along to all subsequent chained resultset objects that get created.
# This allows us to apply the base_rs exactly one time without causing
# a deep recursion loop. 
#
# We also save the reference to the condition added by base_rs so we
# can remove it again, so we have the extra ability to get around
# the base_rs restrictions if we need to using the special accessor
# method native_rs. Because of the stacked design, with resultset's
# being progressively filtered/limited with each new chained call, this 
# is the only practical way to accomplish this. 
#
# The whole purpose of this is to be able to set useful defaults without 
# having to call a custom/special search method in all locations, yet
# still preserving a way to get to the original, unfiltered Rs.
#
# This module is the successor to RapidApp::DBIC::ResultSet::BaseConditions,
# accomplishing the same things as that module yet wihtout the need
# to learn a special API. All that is needed to use this module is
# define an accessor method 'base_rs' in exactly the same way as any
# custom search/resultset method accessor would be setup in a ResultSet
# class, except instead of having to manually call base_rs, it becomes
# the base/default, with access to the original provided by calling
# native_rs.


# Global package variable can be set to disable base_rs and revert
# to normal DBIx::Class::ResultSet behavior:
our $DISABLED = 0;

# Define base_rs in the consuming ResultSet class. Should return a chained
# ResultSet object, i.e. return $self->search_rs( $SEARCH, $ATTR );
sub base_rs { die "Virtual method!" }

sub search_rs {
	my $self = (shift)->_get_apply_base_rs;
	return $self->next::method(@_);
}

### UPDATE: This single updated method solves the real count problem in the below,
### now removed "Issue 13305" workaround
sub as_subselect_rs {
	my $self = (shift)->_get_apply_base_rs;
	
	# Set DISABLED to prevent the base_rs from being applied during the native
	# as_subselect_rs call which creates a new fresh object and calls search() 
	local $DISABLED = 1;
	my $subRs = $self->next::method(@_);
	
	# manually set the _base_rs_applied flag on the newly created rs object so it
	# won't be applied again on any additional searches chained
	return $subRs->search_rs({},{ _base_rs_applied => 1 });
}

###-----------------------
### Issue 13305: Fragile workaround for bug where DBIC's count
### implementation called ->search_rs again in nested resultset, and BaseRs
### puts on the where clause where it shouldn't.
###
### At the time 'count' is called, the base_rs is probably already applied to
### our {attrs}, but we make sure, first.  We then set DISABLED so it won't
### get applied to any newly created outer resultset.
###
### The actual mechanics of creating the outer resultset of the nested query
### depends on the database driver.  See Dbic::Class::ResultSet->_count_subq_rs
### for details.  This seems to be where our "_base_rs_applied" flag gets lost.
###
##sub count_rs :Debug {
##	my $self= shift;
##	$self = $self->_get_apply_base_rs unless ($DISABLED);
##	
##	local $DISABLED= 1;
##	$self->SUPER::count_rs(@_);
##}
###
### also, count does not call count_rs, so we override this one too.
###
##sub count :Debug {
##	my $self= shift;
##	$self = $self->_get_apply_base_rs unless ($DISABLED);
##	
##	local $DISABLED= 1;
##	$self->SUPER::count(@_);
##}
##
##sub count_literal :Debug{
##	my $self= shift;
##	$self = $self->_get_apply_base_rs unless ($DISABLED);
##	
##	local $DISABLED= 1;
##	$self->SUPER::count_literal(@_);
##}
##
## end workaround
##------------------------

sub _get_apply_base_rs {
	my $Rs = shift;
	return $Rs if ($Rs->{attrs}->{_base_rs_applied} || $DISABLED);
	
	$Rs = $Rs->SUPER::search_rs({},{ _base_rs_applied => 1 })->base_rs;
	return $Rs->SUPER::search_rs({},{ _base_rs_condition_ref => $Rs->{attrs}->{where} })
}


# This is ugly but works. This method returns a ResultSet object with
# the condition added by base_rs removed without changing the data in
# other ResultSet objects. Because of how the reference tree is structured,
# the only way to do this is to make a global change to the where, clone
# it, and then make a global change to put it back. This should probably be
# profiled to see how expensive this is. It would be great to find another
# way of doing this. 
sub native_rs {
	my $self = shift;
	my $Rs = $self->search_rs({},{ where => {} });
	
	my $type = ref($Rs->{attrs}->{_base_rs_condition_ref}) or return $self;
	
	# 1. Save the contents of the base condition:
	my $orig_cond = clone($Rs->{attrs}->{_base_rs_condition_ref});
	
	# 2. Temporarily set the base condition to be empty: 
	%{ $Rs->{attrs}->{_base_rs_condition_ref} } = () if ($type eq 'HASH');
	@{ $Rs->{attrs}->{_base_rs_condition_ref} } = () if ($type eq 'ARRAY');
	
	# 3. Clone the where clause hashref in its current state with the empty base condition:
	my $where = clone($Rs->{attrs}->{where});
	
	# 4. Set the base condition back to its original contents:
	%{ $Rs->{attrs}->{_base_rs_condition_ref} } = %$orig_cond if ($type eq 'HASH');
	@{ $Rs->{attrs}->{_base_rs_condition_ref} } = @$orig_cond if ($type eq 'ARRAY');
	
	# 5. Use the new where clause for this ResultSet object
	$Rs->{attrs} = { %{$Rs->{attrs}}, where => $where };
	
	### -- vv -- Proof that this is working as expected:
	#print STDERR YELLOW . "New WHERE:\n" . Dumper($Rs->search_rs->{attrs}->{where}) . CLEAR;
	#print STDERR GREEN . "\nOriginal WHERE:\n" .Dumper($self->search_rs->{attrs}->{where}) . CLEAR;
	### -- ^^ --
	
	return $Rs;
}

# Useful debug function, not directly specific to this module, useful for any ResultSet. Dumps
# what *would* be the SQL if the ResultSet were executed now. Uses the same mechanism as 
# DBIC_TRACE=1 (which needs to be on for this to work) 
sub dump_effective_sql {
	my $self = shift;
	my $debug_obj = $self->result_source->storage->debugobj;
	my ($sql, $bindargs) = @${$self->as_query};
	
	print STDERR BOLD . "\n\ndump_effective_sql():\n" . CLEAR;
	$debug_obj->print($sql, $bindargs);
	print STDERR "\n\n\n";
}

1;
