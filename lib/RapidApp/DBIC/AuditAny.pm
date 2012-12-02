package RapidApp::DBIC::AuditAny;
use Moose;

use RapidApp::Include qw(sugar perlutil);

use RapidApp::DBIC::AuditAny::AuditContext;
use Class::MOP::Class;

has 'schema', is => 'ro', required => 1, isa => 'DBIx::Class::Schema';
#has 'changelog_action_source', is => 'ro', isa => 'Str', required => 1;

has 'track_immutable', is => 'ro', isa => 'Bool', default => 0;
has 'track_actions', is => 'ro', isa => 'ArrayRef', default => sub { [qw(insert update delete)] };

has 'tracked_action_functions', is => 'ro', isa => 'HashRef', default => sub {{}};

has 'tracked_sources', is => 'ro', isa => 'HashRef[Str]', default => sub {{}};
has 'calling_action_function', is => 'ro', isa => 'HashRef[Bool]', default => sub {{}};


sub BUILD {
	my $self = shift;
	$self->_bind_schema;
}


sub _init_schema_class_attribute {
	my $self = shift;
	return if ($self->schema->can('auditany'));
	my $class = ref($self->schema) or die "schema is not a reference";
	
	my $meta = Class::MOP::Class->initialize($class);
	my $immutable = $meta->is_immutable;
	
	die "Won't add 'auditany' attribute to immutable Schema Class '$class' " .
	 '(hint: did you forget to remove __PACKAGE__->meta->make_immutable ??)' .
	 ' - to force/override, set "track_immutable" to true.'
		if ($immutable && !$self->track_immutable);
	
	# Tempory turn mutable back on, saving any immutable_options, first:
	my %immut_opts = ();
	if($immutable) {
		%immut_opts = $meta->immutable_options;
		$meta->make_mutable;
	}
	
	$meta->add_attribute( 
		auditany => ( 
			accessor => 'auditany',
			reader => 'auditany',
			writer => 'set_auditany',
			default => undef
		)
	);
	
	$meta->make_immutable(%immut_opts) if ($immutable);
}

sub _bind_schema {
	my $self = shift;
	$self->_init_schema_class_attribute;
	
	die "Supplied Schema instance already has a bound AuditAny instance!" 
		if ($self->schema->auditany);
		
	return $self->schema->set_auditany($self);
}



sub track_sources {
	my ($self,@sources) = @_;
	
	foreach my $name (@sources) {
		my $Source = $self->schema->source($name) or die "Bad Result Source name '$name'";
		my $source_name = $Source->source_name;
		
		#die "The Log Source (" . $class->log_source_name . ") cannot track itself!!"
		#	if ($source_name eq $class->log_source_name);
		
		# Skip sources we've already setup:
		return if ($self->tracked_sources->{$source_name});
		
		$self->_add_action_tracker($source_name,$_) for (@{$self->track_actions});
		$self->tracked_sources->{$source_name} = 1;
	}
}

sub track_all_sources {
	my ($self,@exclude) = @_;
	#$class->_init;
	
	#push @exclude, $class->log_source_name;
	
	# temp - auto exclude sources without exactly one primary key
	foreach my $source_name ($self->schema->sources) {
		my $Source = $self->schema->source($source_name);
		push @exclude, $source_name unless (scalar($Source->primary_columns) == 1);
	}
	
	my %excl = map {$_=>1} @exclude;
	return $self->track_sources(grep { !$excl{$_} } $self->schema->sources);
}


our $NESTED_CALL = 0;
sub _add_action_tracker {
	my $self = shift;
	my $source_name = shift;
	my $action = shift;
	die "Bad action '$action'" unless ($action ~~ @{$self->track_actions});
	
	my $Source = $self->schema->source($source_name);
	my $result_class = $self->schema->class($source_name);
	my $func_name = $result_class . '::' . $action;
	
	return if $self->tracked_action_functions->{$func_name}++;
	
	my $applied_attr = '_auditany_' . $action . '_tracker_applied';
	return if ($result_class->can($applied_attr));
	
	my $meta = Class::MOP::Class->initialize($result_class);
	my $immutable = $meta->is_immutable;
	
	die "Won't add tracker/modifier method to immutable Result Class '$result_class' " .
	 '(hint: did you forget to remove __PACKAGE__->meta->make_immutable ??)' .
	 ' - to force/override, set "track_immutable" to true.'
		if ($immutable && !$self->track_immutable);
	
	# Tempory turn mutable back on, saving any immutable_options, first:
	my %immut_opts = ();
	if($immutable) {
		%immut_opts = $meta->immutable_options;
		$meta->make_mutable;
	}
		
	#my @pri_keys = $Source->primary_columns;
	#die "Source '$source_name' has " . scalar(@pri_keys) . " primary keys. " .
	# "Only sources with exactly 1 are currently supported." unless (scalar(@pri_keys) == 1);
	#
	#my %base_data = (
	#	action 				=> $action,
	#	source 				=> $Source->source_name,
	#	table 				=> $Source->from,
	#	pri_key_column		=> $pri_keys[0]
	#);
	
	
	
	$meta->add_around_method_modifier( $action => sub {
		my $orig = shift;
		my $Row = shift;
		
		# This method modifier is applied to the entire result class. Call/return the
		# unaltered original method unless the Row is tied to a schema instance that
		# is being tracked by an AuditAny which is configured to track the current
		# action function. Also, make sure this call is not already nested to prevent
		# deep recursion
		my $AuditAny = $Row->result_source->schema->auditany;
		return $Row->$orig(@_) if (
			! $AuditAny ||
			! $AuditAny->tracked_action_functions->{$func_name} ||
			$AuditAny->calling_action_function->{$func_name}
		);
		
		$AuditAny->calling_action_function->{$func_name} = 1;
		
		my $AuditContext = RapidApp::DBIC::AuditAny::AuditContext->new(
			AuditObj 	=> $self,
			Row			=> $Row
		);
		my $result = $AuditContext->proxy_action($action,@_);
		
		$AuditAny->calling_action_function->{$func_name} = 0;
		
		scream($AuditContext->get_changes);
		
		return $result;
	}) or die "Unknown error setting up '$action' modifier on '$result_class'";
	
	$result_class->mk_classdata($applied_attr);
	$result_class->$applied_attr(1);
	
	# Restore immutability to the way to was:
	$meta->make_immutable(%immut_opts) if ($immutable);
}



#has 'data_points', isa => 'HashRef[HashRef]', lazy_build => 1;
#sub _build_data_points {
#	my $self = shift;
#
#}



1;