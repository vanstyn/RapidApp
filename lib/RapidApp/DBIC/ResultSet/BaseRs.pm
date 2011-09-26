package RapidApp::DBIC::ResultSet::BaseRs;
use base 'DBIx::Class::ResultSet';

use RapidApp::Include qw(sugar perlutil);
use RapidApp::Data::Dmap;
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


# Define base_rs in the consuming ResultSet class. Should return a chained
# ResultSet object, i.e. return $self->search_rs( $SEARCH, $ATTR );
sub base_rs { (shift) }

sub search_rs {
	my $self = (shift)->_get_apply_base_rs;
	return $self->SUPER::search_rs(@_);
}

sub _get_apply_base_rs {
	my $Rs = shift;
	return $Rs if ($Rs->{attrs}->{_base_rs_applied});
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
	
	my $new_ref = {};
	my $old_ref = $Rs->{attrs}->{_base_rs_condition_ref};
	
	# 1. Find the base condition within the current where and replace it with an empty hashref:
	dmap { return $new_ref if ($_ == $old_ref); return $_; } $Rs->{attrs}->{where};
	
	# 2. Clone the where clause hashref in its current state:
	my $where = clone($Rs->{attrs}->{where});
	
	# 3. Find the empty hashref from step 1 and replace it with the original:
	dmap { return $old_ref if ($_ == $new_ref); return $_; } $Rs->{attrs}->{where};
	
	# 4. Use the new where clause for this ResultSet object
	$Rs->{attrs} = { %{$Rs->{attrs}}, where => $where };
	
	### -- vv -- Proof that this is working as expected:
	#print STDERR YELLOW . "New WHERE:\n" . Dumper($Rs->search_rs->{attrs}->{where}) . CLEAR;
	#print STDERR GREEN . "\nOriginal WHERE:\n" .Dumper($self->search_rs->{attrs}->{where}) . CLEAR;
	### -- ^^ --
	
	return $Rs;
}


1;
