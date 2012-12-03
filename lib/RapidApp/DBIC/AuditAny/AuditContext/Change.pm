package RapidApp::DBIC::AuditAny::AuditContext::Change;
use Moose;
extends 'RapidApp::DBIC::AuditAny::AuditContext';

use RapidApp::Include qw(sugar perlutil);

use Text::TabularDisplay;

# ***** PRIVATE Object Class *****

has 'SourceContext', is => 'ro', required => 1;
has 'Row', is => 'ro', required => 1;
has 'action', is => 'ro', isa => 'Str', required => 1;

# whether or not to fetch the row from storage again after the action
# to identify changes
has 'new_columns_from_storage', is => 'ro', isa => 'Bool', default => 1;

has 'allowed_actions', is => 'ro', isa => 'ArrayRef', lazy_build => 1;
sub _build_allowed_actions { [qw(insert update delete)] };

has 'executed', is => 'rw', isa => 'Bool', default => 0, init_arg => undef;
has 'recorded', is => 'rw', isa => 'Bool', default => 0, init_arg => undef;

sub ResultSource { (shift)->SourceContext->ResultSource }
sub source { (shift)->SourceContext->source }
sub pri_key_column { (shift)->SourceContext->pri_key_column }
sub pri_key_count { (shift)->SourceContext->pri_key_column }
sub primary_key_separator { (shift)->SourceContext->primary_key_separator }
sub primary_columns { (shift)->SourceContext->primary_columns }
sub class { (shift)->SourceContext->class }

sub get_pri_key_value {
	my $self = shift;
	my $Row = shift;
	my @num = $self->pri_key_count;
	return undef unless (scalar(@num) > 0);
	return $Row->get_column($self->pri_key_column) if (scalar(@num) == 1);
	my $sep = $self->primary_key_separator;
	return join($sep, map { $Row->get_column($_) } $self->primary_columns );
}

has 'pri_key_value', is => 'ro', isa => 'Maybe[Str]', lazy => 1, default => sub { 
	my $self = shift;
	$self->enforce_executed;
	return $self->get_pri_key_value($self->Row);
};

has 'orig_pri_key_value', is => 'ro', isa => 'Maybe[Str]', lazy => 1, default => sub { 
	my $self = shift;
	return $self->get_pri_key_value($self->origRow);
};

has 'change_ts', is => 'ro', isa => 'DateTime', lazy => 1, default => sub {
	my $self = shift;
	$self->enforce_unexecuted;
	return DateTime->now( time_zone => 'local' );
};

has 'dirty_columns', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	$self->enforce_unexecuted;
	return { $self->Row->get_dirty_columns };
};


has 'origRow', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	$self->enforce_unexecuted;
	return $self->Row->in_storage ? $self->Row->get_from_storage : $self->Row;
};

has 'newRow', is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	$self->enforce_executed;
	
	return $self->Row unless (
		$self->Row->in_storage and
		$self->new_columns_from_storage
	);
	return $self->Row->get_from_storage;
};




sub BUILD {
	my $self = shift;
	$self->dirty_columns;
	$self->origRow;
	$self->old_columns;
}


has 'action_id_map', is => 'ro', isa => 'HashRef[Str]', lazy_build => 1;
sub _build_action_id_map {{
	insert => 1,
	update => 2,
	delete => 3
}}

sub action_id {
	my $self = shift;
	my $action = $self->action or return undef;
	my $id = $self->action_id_map->{$action} or die "Error looking up action_id";
	return $id;
}


has 'datapoint_values', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	$self->enforce_executed;
	return { map { $_->name => $_->get_value($self) } $self->get_context_datapoints('change') };
};

has 'all_datapoint_values', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	return {
		%{ $self->SourceContext->all_datapoint_values },
		%{ $self->datapoint_values }
	};
};

sub get_named_datapoint_values {
	my $self = shift;
	my @names = (ref($_[0]) eq 'ARRAY') ? @{ $_[0] } : @_; # <-- arg as array or arrayref
	my $data = $self->all_datapoint_values;
	return map { $_ => (exists $data->{$_} ? $data->{$_} : undef) } @names;
}

sub enforce_unexecuted {
	my $self = shift;
	die "Error: Audit action already executed!" if ($self->executed);
}

sub enforce_executed {
	my $self = shift;
	die "Error: Audit action not executed yet!" unless ($self->executed);
}


sub record {
	my $self = shift;
	$self->enforce_unexecuted;
	$self->change_ts;
	$self->executed(1);
	$self->newRow;
	$self->recorded(1);
}

around 'Row' => sub {
	my $orig = shift;
	my $self = shift;
	return $self->recorded ? $self->newRow : $self->$orig(@_);
};

#sub proxy_action {
#	my $self = shift;
#	my $action = shift;
#	my $columns = shift;
#	
#	die "Bad action '$action'" unless ($action ~~ @{$self->allowed_actions});
#	
#	$self->enforce_unexecuted;
#	$self->origRow;
#	$self->action($action);
#	$self->executed(1);
#	
#	$self->Row->set_inflated_columns($columns) if $columns;
#	
#	$self->dirty_columns({ $self->Row->get_dirty_columns });
#	
#	$self->change_ts( DateTime->now( time_zone => 'local' ) );
#	return $self->Row->$action;
#}

has 'old_columns', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	return {} unless ($self->origRow->in_storage);
	return { $self->origRow->get_columns };
};

has 'new_columns', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	return {} unless ($self->newRow->in_storage);
	return { $self->newRow->get_columns };
};


has 'column_changes', is => 'ro', isa => 'HashRef[Object]', lazy => 1, default => sub {
	my $self = shift;
	$self->enforce_executed;
	
	my $old = $self->old_columns;
	my $new = $self->new_columns;
	
	# This logic is duplicated in DbicLink2. Not sure how to avoid it, though,
	# and keep a clean API
	my @changed = ();
	foreach my $col (uniq(keys %$new,keys %$old)) {
		next if (!(defined $new->{$col}) and !(defined $old->{$col}));
		next if (
			defined $new->{$col} and defined $old->{$col} and 
			$new->{$col} eq $old->{$col}
		);
		push @changed, $col;
	}
	
	my %col_context = ();
	my $class = $self->AuditObj->column_context_class;
	foreach my $column (@changed) {
		my $ColumnContext = $class->new(
			AuditObj => $self->AuditObj,
			ChangeContext => $self,
			column_name => $column, 
			old_value => $old->{$column}, 
			new_value => $new->{$column},
		);
		$col_context{$ColumnContext->column_name} = $ColumnContext;
	}
	
	return \%col_context;
};


has 'column_datapoint_values', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	my @Contexts = values %{$self->column_changes};
	return { map { $_->column_name => $_->datapoint_values } @Contexts };
};

sub dump_change {
	my $self = shift;
	return Dumper($self->column_datapoint_values);
}


has 'column_changes_ascii', is => 'ro', isa => 'Str', lazy => 1, default => sub {
	my $self = shift;
	my $table = $self->column_changes_arr_arr_table;
	return $self->arr_arr_ascii_table($table);
};

has 'column_changes_json', is => 'ro', isa => 'Str', lazy => 1, default => sub {
	my $self = shift;
	my $table = $self->column_changes_arr_arr_table;
	return encode_json($table);
};


has 'column_changes_arr_arr_table', is => 'ro', isa => 'ArrayRef',
 lazy => 1, default => sub {
	my $self = shift;
	my @cols = $self->get_context_datapoint_names('column');
	
	my @col_datapoints = values %{$self->column_datapoint_values};
	
	scream(\@col_datapoints);
	
	my $table = [\@cols];
	foreach my $col_data (@col_datapoints) {
		my @row = map { $col_data->{$_} || undef } @cols;
		push @$table, \@row;
	}
	
	return $table;
};



sub arr_arr_ascii_table {
	my $self = shift;
	my $table = shift;
	die "Supplied table is not an arrayref" unless (ref($table) eq 'ARRAY');
	
	require Text::TabularDisplay;
	require Text::Wrap;
	
	my $t = Text::TabularDisplay->new;
	
	local $Text::Wrap::columns = 52;
	
	my $header = shift @$table;
	die "Encounted non-arrayref table row" unless (ref($header) eq 'ARRAY');
	
	$t->add(@$header);
	$t->add('');
	
	foreach my $row (@$table) {
		die "Encounted non-arrayref table row" unless (ref($row) eq 'ARRAY');
		$t->add( map { Text::Wrap::wrap('','',$_) } @$row );
	}
	
	return $t->render;
}


### Special TableSpec-specific datapoints:


has 'has_TableSpec', is => 'ro', isa => 'Bool', lazy => 1, default => sub {
	my $self = shift;
	return $self->class->can('TableSpec_get_conf') ? 1 : 0;
};

has 'fk_map', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	return {} unless ($self->has_TableSpec);
	return $self->class->TableSpec_get_conf('relationship_column_fks_map') || {};
};

has 'column_properties', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	return {} unless ($self->has_TableSpec);
	return { $self->class->TableSpec_get_conf('columns') };
};

1;