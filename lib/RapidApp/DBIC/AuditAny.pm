package RapidApp::DBIC::AuditAny;
use Moose;

use RapidApp::Include qw(sugar perlutil);

use Class::MOP::Class;

#$SIG{__DIE__} = sub { confess(shift) };

has 'schema', is => 'ro', required => 1, isa => 'DBIx::Class::Schema';
has 'track_immutable', is => 'ro', isa => 'Bool', default => 0;
has 'track_actions', is => 'ro', isa => 'ArrayRef', default => sub { [qw(insert update delete)] };
has 'allow_multiple_auditors', is => 'ro', isa => 'Bool', default => 0; 

has 'source_context_class', is => 'ro', default => 'RapidApp::DBIC::AuditAny::AuditContext::Source';
has 'change_context_class', is => 'ro', default => 'RapidApp::DBIC::AuditAny::AuditContext::Change';
has 'changeset_context_class', is => 'ro', default => 'RapidApp::DBIC::AuditAny::AuditContext::ChangeSet';
has 'column_context_class', is => 'ro', default => 'RapidApp::DBIC::AuditAny::AuditContext::Column';
has 'default_datapoint_class', is => 'ro', default => 'RapidApp::DBIC::AuditAny::DataPoint';
has 'collector_class', is => 'ro', required => 1;
has 'collector_params', is => 'ro', isa => 'HashRef', default => sub {{}};
has 'primary_key_separator', is => 'ro', isa => 'Str', default => '|~|';
has 'datapoints', is => 'ro', isa => 'ArrayRef[Str]', lazy_build => 1;
has 'datapoint_configs', is => 'ro', isa => 'ArrayRef[HashRef]', default => sub {[]};
has 'auto_include_user_defined_datapoints', is => 'ro', isa => 'Bool', default => 1;
has 'rename_datapoints', is => 'ro', isa => 'Maybe[HashRef[Str]]', default => undef;
has 'disable_datapoints', is => 'ro', isa => 'ArrayRef', default => sub {[]};

has 'collector', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	eval 'require ' . $self->collector_class;
	return ($self->collector_class)->new( 
		%{$self->collector_params},
		AuditObj => $self
	);
};



# Any sources within the tracked schema that the collector is writing to; these
# sources are not allowed to be tracked because it would create infinite recursion:
has 'log_sources', is => 'ro', isa => 'ArrayRef[Str]', lazy => 1, init_arg => undef, default => sub {
	my $self = shift;
	return $self->collector->writes_bound_schema_sources;
};



has 'tracked_action_functions', is => 'ro', isa => 'HashRef', default => sub {{}};

has 'tracked_sources', is => 'ro', isa => 'HashRef[Str]', default => sub {{}};
has 'calling_action_function', is => 'ro', isa => 'HashRef[Bool]', default => sub {{}};
has 'active_changeset', is => 'rw', isa => 'Maybe[Object]', default => undef;
has 'auto_finish', is => 'rw', isa => 'Bool', default => 0;

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
	push @configs, { name => $_, context => 'base', method => $_  } for (@base_points);
	
	# direct passthroughs to the AuditSourceContext object:
	my @source_points = qw(source class from table pri_key_column pri_key_count);
	push @configs, { name => $_, context => 'source', method => $_  } for (@source_points);
	
	# direct passthroughs to the AuditChangeContext object:
	my @change_points = (
		(qw(change_ts action action_id pri_key_value orig_pri_key_value)),
		(qw(column_changes_json column_changes_ascii))
	);
	push @configs, { name => $_, context => 'change', method => $_ } for (@change_points);
	
	# direct passthroughs to the Column data hash (within the Change context object):
	my @column_points = qw(column_header column_name old_value new_value old_display_value new_display_value);
	push @configs, { name => $_, context => 'column', method => $_  } for (@column_points);
	

	
	# strip out any being redefined:
	my %cust = map {$_->{name}=>1} @{$self->datapoint_configs};
	@configs = grep { !$cust{$_->{name}} } @configs;
	
	# Set flag to mark the configs that were user defined
	$_->{user_defined} = 1 for (@{$self->datapoint_configs});
	
	push @configs, @{$self->datapoint_configs};
	
	return @configs;
}


sub _build_datapoints {[qw(
change_ts
action
source
pri_key_value
column_name
column_header
old_value
new_value
old_display_value
new_display_value
column_changes_ascii
column_changes_json
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

sub get_context_datapoint_names {
	my $self = shift;
	return map { $_->name } $self->get_context_datapoints(@_);
}


sub local_datapoint_data { (shift)->base_datapoint_values }
has 'base_datapoint_values', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	return { map { $_->name => $_->get_value($self) } $self->get_context_datapoints('base') };
};

sub _init_datapoints {
	my $self = shift;
	
	my @configs = $self->_get_datapoint_configs;
	
	
	
	if($self->rename_datapoints) {
		my $rename = $self->rename_datapoints;
		
		@{$self->datapoints} = map { $rename->{$_} || $_ } @{$self->datapoints};
		
		$_->{name} = (exists $rename->{$_->{name}} ? $rename->{$_->{name}} : $_->{name})
			for (@configs);
	}
	
	my %seen = ();
	$seen{$_}++ and die "Duplicate datapoint name '$_'" for (@{$self->datapoints});
	
	my %disable = map {$_=>1} @{$self->disable_datapoints};
	my %activ = map {$_=>1} grep { !$disable{$_} } @{$self->datapoints};
	
	if($self->auto_include_user_defined_datapoints) {
		$activ{$_->{name}} = 1 for(grep { $_->{name} && $_->{user_defined} } @configs);
	}
	
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
	
	my $collect = exists $opts{collect} ? delete $opts{collect} : undef;
	if ($collect) {
		die "'collect' cannot be used with 'collector_params', 'collector_class' or 'collector'"
			if ($opts{collector_params} || $opts{collector_class} || $opts{collector});
			
		$opts{collector_class} = 'RapidApp::DBIC::AuditAny::Collector';
		$opts{collector_params} = { collect_coderef => $collect };
	}
	
	if($opts{collector}) {
		die "'collector' cannot be used with 'collector_params', 'collector_class' or 'collect'"
			if ($opts{collector_params} || $opts{collector_class} || $opts{collect});
	}
	
	my $self = $class->new(%opts);
	
	$self->track_sources(@$sources) if ($sources);
	$self->track_all_sources if ($track_all)

}

sub BUILD {
	my $self = shift;
	
	eval 'require ' . $self->change_context_class;
	eval 'require ' . $self->changeset_context_class;
	eval 'require ' . $self->source_context_class;
	eval 'require ' . $self->column_context_class;
	eval 'require ' . $self->collector_class;
	eval 'require ' . $self->default_datapoint_class;
	
	$self->_init_datapoints;
	$self->_bind_schema;
	
	# init collector object:
	$self->collector;
}


sub _init_apply_schema_class {
	my $self = shift;
	return if ($self->schema->can('auditors'));
	my $class = ref($self->schema) or die "schema is not a reference";
	
	my $meta = Class::MOP::Class->initialize($class);
	
	# If this class has already be updated:
	return if ($meta->has_attribute('auditors'));
	
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
		auditors => ( 
			accessor => 'auditors',
			reader => 'auditors',
			writer => 'set_auditors',
			default => undef
		)
	);
	$meta->add_method( add_auditor => sub { push @{(shift)->auditors}, @_ } );
	
	$meta->add_around_method_modifier( 'txn_do' => sub {
		my $orig = shift;
		my $Schema = shift;
		
		# This method modifier is applied to the entire schema class. Call/return the
		# unaltered original method unless the Row is tied to a schema instance that
		# is being tracked by an AuditAny which is configured to track the current
		# action function. Also, make sure this call is not already nested to prevent
		# deep recursion
		my $Auditors = $Schema->auditors || [];
		return $Schema->$orig(@_) unless (scalar(@$Auditors) > 0);
		
		my @ChangeSets = ();
		foreach my $AuditAny (@$Auditors) {
			next if (
				ref($self) ne ref($AuditAny) ||
				$AuditAny->active_changeset
			);
			push @ChangeSets, $AuditAny->start_changeset;
		};
		
		return $Schema->$orig(@_) unless (scalar(@ChangeSets) > 0);
		
		my $result;
		my @args = @_;
		try {
			$result = $Schema->$orig(@args);
			$_->finish for (@ChangeSets);
		}
		catch {
			my $err = shift;
			# Clean up:
			try{$_->AuditObj->clear_changeset} for (@ChangeSets);
			# Re-throw:
			die $err;
		};
		return $result;
	});
		
	$meta->make_immutable(%immut_opts) if ($immutable);
}

sub start_changeset {
	my $self = shift;
	die "Cannot start_changeset because a changeset is already active" if ($self->active_changeset);
	
	my $class = $self->changeset_context_class;
	$self->active_changeset($class->new( AuditObj => $self ));
	return $self->active_changeset;
}

sub finish_changeset {
	my $self = shift;
	die "Cannot finish_changeset because there isn't one active" unless ($self->active_changeset);
	
	$self->collector->record_changes($self->active_changeset);
	$self->clear_changeset;
	return 1;
}

sub clear_changeset {
	my $self = shift;
	$self->active_changeset(undef);
	$self->auto_finish(0);
}

sub _bind_schema {
	my $self = shift;
	$self->_init_apply_schema_class;
	
	$self->schema->set_auditors([]) unless ($self->schema->auditors);
	
	die "Supplied Schema instance already has a bound Auditor - to allow multple " .
	 "Auditors, set 'allow_multiple_auditors' to true"
		if(scalar(@{$self->schema->auditors}) > 0 and ! $self->allow_multiple_auditors);
	
	$_ == $self and return for(@{$self->schema->auditors});
	
	return $self->schema->add_auditor($self);
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
		my $columns = $_[0];
	
		# This method modifier is applied to the entire result class. Call/return the
		# unaltered original method unless the Row is tied to a schema instance that
		# is being tracked by an AuditAny which is configured to track the current
		# action function. Also, make sure this call is not already nested to prevent
		# deep recursion
		my $Auditors = $Row->result_source->schema->auditors || [];
		return $Row->$orig(@_) unless (scalar(@$Auditors) > 0);
		
		$Row->set_inflated_columns($columns) if ($columns && $action ne 'delete');
		
		# Before action is called:
		my @Trackers = ();
		foreach my $AuditAny (@$Auditors) {
			next if (
				ref($self) ne ref($AuditAny) ||
				! $AuditAny->tracked_action_functions->{$func_name} ||
				$AuditAny->calling_action_function->{$func_name}
			);
			
			unless ($AuditAny->active_changeset) {
				$AuditAny->start_changeset;
				$AuditAny->auto_finish(1);
			}
			
			$AuditAny->calling_action_function->{$func_name} = 1;
			my $class = $AuditAny->change_context_class;
			my $ChangeContext = $class->new(
				AuditObj				=> $AuditAny,
				SourceContext		=> $AuditAny->tracked_sources->{$source_name},
				ChangeSetContext	=> $AuditAny->active_changeset,
				Row 					=> $Row,
				action				=> $action
			) or next;
			push @Trackers, $ChangeContext;
		}
		
		my $result;
		try {
			# call action:
			$result = $Row->$orig;
			
			# After action is called:
			foreach my $ChangeContext (@Trackers) {
				$ChangeContext->record;
				my $AuditAny = $ChangeContext->AuditObj;
				$AuditAny->record_change($ChangeContext);
				$AuditAny->calling_action_function->{$func_name} = 0;
			}
		}
		catch {
			my $err = shift;
			# Still Clean up:
			foreach my $ChangeContext (@Trackers) {
				try {
					my $AuditAny = $ChangeContext->AuditObj;
					try{$AuditAny->clear_changeset};
					$AuditAny->calling_action_function->{$func_name} = 0;
				};
			}
			# Re-throw:
			die $err;
		};
		return $result;
	}) or die "Unknown error setting up '$action' modifier on '$result_class'";
	
	$result_class->mk_classdata($applied_attr);
	$result_class->$applied_attr(1);
	
	# Restore immutability to the way to was:
	$meta->make_immutable(%immut_opts) if ($immutable);
}


sub record_change {
	my $self = shift;
	my $ChangeContext = shift;
	die "Cannot record_change without an active changeset" unless ($self->active_changeset);
	$self->active_changeset->add_changes($ChangeContext);
	$self->finish_changeset if ($self->auto_finish);
}


1;