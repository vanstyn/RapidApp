package RapidApp::DBIC::AuditAny;
use Moose;

use RapidApp::Include qw(sugar perlutil);

use Class::MOP::Class;

#$SIG{__DIE__} = sub { confess(shift) };

has 'schema', is => 'ro', required => 1, isa => 'DBIx::Class::Schema';
has 'source_context_class', is => 'ro', default => 'RapidApp::DBIC::AuditAny::AuditContext::Source';
has 'change_context_class', is => 'ro', default => 'RapidApp::DBIC::AuditAny::AuditContext::Change';
has 'column_context_class', is => 'ro', default => 'RapidApp::DBIC::AuditAny::AuditContext::Column';
has 'default_datapoint_class', is => 'ro', default => 'RapidApp::DBIC::AuditAny::DataPoint';
has 'collector_class', is => 'ro', required => 1;
has 'collector_params', is => 'ro', isa => 'HashRef', default => sub {{}};
has 'Collector', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	eval 'require ' . $self->collector_class;
	return ($self->collector_class)->new( 
		%{$self->collector_params},
		AuditObj => $self
	);
};

has 'primary_key_separator', is => 'ro', isa => 'Str', default => '|~|';

has 'logs_to_own_schema', is => 'ro', isa => 'Bool', lazy => 1, init_arg => undef, default => sub {
	my $self = shift;
	return ($self->Collector->uses_schema == $self->schema) ? 1 : 0;
};

has 'log_sources', is => 'ro', isa => 'ArrayRef[Str]', lazy => 1, init_arg => undef, default => sub {
	my $self = shift;
	return [] unless ($self->logs_to_own_schema);
	return [ $self->Collector->uses_sources ];
};

has 'track_immutable', is => 'ro', isa => 'Bool', default => 0;
has 'track_actions', is => 'ro', isa => 'ArrayRef', default => sub { [qw(insert update delete)] };

has 'tracked_action_functions', is => 'ro', isa => 'HashRef', default => sub {{}};

has 'tracked_sources', is => 'ro', isa => 'HashRef[Str]', default => sub {{}};
has 'calling_action_function', is => 'ro', isa => 'HashRef[Bool]', default => sub {{}};
has 'datapoint_configs', is => 'ro', isa => 'ArrayRef[HashRef]', default => sub {[]};


sub _get_datapoint_configs {
	my $self = shift;
	
	# Here are the built-in datapoints:
	my @configs = (
		{
			name => 'schema', context => 'base',
			method	=> sub { ref (shift)->schema }
		}
	);
	
	# direct passthroughs to the AuditAny object:
	my @base_points = qw();
	push @configs, { name => $_, context => 'base', passthrough => 1 } for (@base_points);
	
	# direct passthroughs to the AuditSourceContext object:
	my @source_points = qw(source class from table pri_key_column pri_key_count);
	push @configs, { name => $_, context => 'source', passthrough => 1 } for (@source_points);
	
	# direct passthroughs to the AuditChangeContext object:
	my @change_points = (
		(qw(change_ts action action_id pri_key_value orig_pri_key_value)),
		(qw(change_details_json))
	);
	push @configs, { name => $_, context => 'change', passthrough => 1 } for (@change_points);
	
	# direct passthroughs to the Column data hash (within the Change context object):
	my @column_points = qw(column_header column_name old_value new_value);
	push @configs, { name => $_, context => 'column', passthrough => 1 } for (@column_points);
	

	
	# strip out any being redefined:
	my %cust = map {$_->{name}=>1} @{$self->datapoint_configs};
	@configs = grep { !$cust{$_->{name}} } @configs;
	
	push @configs, @{$self->datapoint_configs};
	
	return @configs;
}

has 'datapoints', is => 'ro', isa => 'ArrayRef', default => sub {[qw(
change_ts
action
source
pri_key_value
column_name
old_value
new_value
)]};

has '_datapoints', is => 'ro', isa => 'HashRef', default => sub {{}};
has '_datapoints_context', is => 'ro', isa => 'HashRef', default => sub {{}};
sub add_datapoints {
	my $self = shift;
	my $class = $self->default_datapoint_class;
	foreach my $cnf (@_) {
		die "'$cnf' not expected ref" unless (ref $cnf);
		$class = delete $cnf->{class} if ($cnf->{class});
		my $DataPoint = ref($cnf) eq $class ? $cnf : $class->new($cnf);
		die "Error creating datapoint object" unless (ref($DataPoint) eq $class);
		die "Duplicate datapoint name '" . $DataPoint->name . "'" if ($self->_datapoints->{$DataPoint->name});
		$self->_datapoints->{$DataPoint->name} = $DataPoint;
		$self->_datapoints_context->{$DataPoint->context}->{$DataPoint->name} = $DataPoint;
	}
}
sub all_datapoints { values %{(shift)->_datapoints} }

sub get_context_datapoints {
	my $self = shift;
	my @contexts = grep { exists $self->_datapoints_context->{$_} } @_;
	return map { values %{$self->_datapoints_context->{$_}} } @contexts;
}

has 'base_datapoint_values', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	return { map { $_->name => $_->get_value($self) } $self->get_context_datapoints('base') };
};

sub _init_datapoints {
	my $self = shift;
	
	my %activ = map {$_=>1} @{$self->datapoints};
	my @configs = $self->_get_datapoint_configs;
	
	foreach my $cnf (@configs) {
		# Do this just to throw the exception for no name:
		$self->add_datapoints($cnf) unless ($cnf->{name});
		
		next unless $activ{$cnf->{name}};
		delete $activ{$cnf->{name}};
		$self->add_datapoints({%$cnf, AuditObj => $self});
	}
	
	die "Unknown datapoint(s) specified (" . join(',',keys %activ) . ')'
		if (scalar(keys %activ) > 0);
}




sub track {
	my $class = shift;
	my %opts = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	die "track cannot be called on object instances" if (ref $class);
	
	#my $collector = exists $opts{collector_params} ? delete $opts{collector_params} : {};
	#die 'collector_params must be a hashref' unless (ref($collector) eq 'HASH');
	
	my $sources = exists $opts{track_sources} ? delete $opts{track_sources} : undef;
	die 'track_sources must be an arrayref' if ($sources and ! ref($sources) eq 'ARRAY');
	
	my $track_all = exists $opts{track_all_sources} ? delete $opts{track_all_sources} : undef;
	
	die "track_sources and track_all_sources are incompatable" if ($sources && $track_all);
	
	my $self = $class->new(%opts);
	
	$self->track_sources(@$sources) if ($sources);
	$self->track_all_sources if ($track_all)

}

sub BUILD {
	my $self = shift;
	
	eval 'require ' . $self->change_context_class;
	eval 'require ' . $self->source_context_class;
	eval 'require ' . $self->column_context_class;
	eval 'require ' . $self->collector_class;
	eval 'require ' . $self->default_datapoint_class;
	
	$self->_init_datapoints;
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
		
		my $class = $self->source_context_class;
		my $AuditSourceContext = $class->new( 
			AuditObj			=> $self, 
			ResultSource	=> $Source
		);
		
		my $source_name = $AuditSourceContext->source;
		
		die "The Log Source (" . $source_name . ") cannot track itself!!"
			if ($source_name ~~ @{$self->log_sources});

		# Skip sources we've already setup:
		return if ($self->tracked_sources->{$source_name});
		
		$self->_add_action_tracker($AuditSourceContext,$_) for (@{$self->track_actions});
		$self->tracked_sources->{$source_name} = $AuditSourceContext;
	}
}

sub track_all_sources {
	my ($self,@exclude) = @_;
	#$class->_init;
	
	push @exclude, @{$self->log_sources};
	
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
	my $AuditSourceContext = shift;
	my $action = shift;
	my $source_name = $AuditSourceContext->source;
	
	die "Bad action '$action'" unless ($action ~~ @{$self->track_actions});
	
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
		my $class = $self->change_context_class;
		my $AuditChangeContext = $class->new( 
			AuditObj			=> $self,
			SourceContext	=> $self->tracked_sources->{$source_name},
			Row 				=> $Row 
		);
		my $result = $AuditChangeContext->proxy_action($action,@_);
		$AuditAny->calling_action_function->{$func_name} = 0;
		
		$AuditAny->record_change($AuditChangeContext);
		
		return $result;
	}) or die "Unknown error setting up '$action' modifier on '$result_class'";
	
	$result_class->mk_classdata($applied_attr);
	$result_class->$applied_attr(1);
	
	# Restore immutability to the way to was:
	$meta->make_immutable(%immut_opts) if ($immutable);
}


sub record_change {
	my $self = shift;
	my $AuditContext = shift;
	
	return $self->Collector->record_change($AuditContext);
}


#has 'data_points', isa => 'HashRef[HashRef]', lazy_build => 1;
#sub _build_data_points {
#	my $self = shift;
#
#}



1;