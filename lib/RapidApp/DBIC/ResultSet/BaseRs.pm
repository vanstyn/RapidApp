package RapidApp::DBIC::ResultSet::BaseRs;
use base 'DBIx::Class::ResultSet';

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
# This module is the successor to RapidApp::DBIC::ResultSet::BaseConditions,
# accomplishing the same things as that module yet wihtout the need
# to learn a special API. All that is needed to use this module is
# define an accessor method 'base_rs' in exactly the same way as any
# custom search/resultset method accessor would be setup in a ResultSet
# class, except instead of having to manually call base_rs, it becomes
# the base/default

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
	return $Rs->SUPER::search_rs({},{ _base_rs_applied => 1 })->base_rs;
}

1;
