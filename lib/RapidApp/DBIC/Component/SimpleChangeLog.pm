package RapidApp::DBIC::Component::SimpleChangeLog;
#use base 'DBIx::Class';
# this is for Attribute::Handlers:
require base; base->import('DBIx::Class::Schema');

use RapidApp::Include qw(sugar perlutil);

__PACKAGE__->mk_classdata( 'log_source_name' );
__PACKAGE__->mk_classdata( 'log_source_column_map' );
__PACKAGE__->mk_classdata( 'track_actions' );

__PACKAGE__->mk_classdata( '_tracked_sources' );
__PACKAGE__->mk_classdata( '_initialized' );

# These are the default mappings of columns for the supplied log Source
# User-defined mappings are optionally specified in 'log_source_column_map'
# Any columns from the default list can be turned off (i.e. set to not store
# the given data point) by setting a value of undef
our %default_column_map = (
	change_ts	=> 'change_ts',
	user_id		=> 'user_id',
	action		=> 'action', 		# insert/update/delete
	schema		=> undef, 			# store the name of the schema, off by default
	source		=> 'source',
	table		=> undef, 			# store the table name
	pri_key		=> 'pri_key', 		# the value of the primary key of the changed row
	diff_change	=> 'diff_change'	# where to store the description of the change

);

sub _init {
	my $class = shift;
	return if ($class->_initialized);
	
	$class->_tracked_sources( {} ) unless ($class->_tracked_sources);
	
	my @actions = qw(insert update delete);
	$class->track_actions( \@actions ) unless ($class->track_actions);
	
	die 'track_actions must be an ArrayRef!' 
		unless (ref($class->track_actions) eq 'ARRAY');
	$_ ~~ @actions or die "Invalid action '$_' - only allowed actions: " . join(',',@actions) 
		for (@{$class->track_actions});
	
	die "No 'log_source_name' declared!" unless ($class->log_source_name);
	my $LogSource = $class->source($class->log_source_name) 
		or die "Invalid log_source_name '" . $class->log_source_name . "'";
	
	$class->log_source_column_map({
		%default_column_map,
		%{ $class->log_source_column_map || {} }
	});
	
	my @required_cols = grep { defined $_ } values %{$class->log_source_column_map};
	my %has_cols = map {$_=>1} $LogSource->columns;
	my @missing_cols = grep { !$has_cols{$_} } @required_cols;
	
	die ref($LogSource) . ' cannot be used as the Log Source because it is missing ' .
	 'the following required columns: ' . join(', ',map {"'$_'"} @missing_cols) 
		if (scalar @missing_cols > 0);
	
	# Normalize:
	$class->log_source_name( $LogSource->source_name );
	
	return $class->_initialized(1);
}

sub track_all_sources {
	my ($class,@exclude) = @_;
	$class->_init;
	
	push @exclude, $class->log_source_name;
	return $class->track_sources(grep { ! $_ ~~ @exclude } $class->sources);
}

sub track_sources {
	my ($class,@sources) = @_;
	$class->_init;
	
	foreach my $name (@sources) {
		my $Source = $class->source($name) or die "Bad Result Source name '$name'";
		my $source_name = $Source->source_name;
		
		die "The Log Source (" . $class->log_source_name . ") cannot track itself!!"
			if ($source_name eq $class->log_source_name);
		
		# Skip sources we've already setup:
		return if ($class->_tracked_sources->{$source_name});
		
		
		## Setup tracking code.....
	
	
		$class->_tracked_sources->{$source_name} = 1;
	}

}


1;__END__
