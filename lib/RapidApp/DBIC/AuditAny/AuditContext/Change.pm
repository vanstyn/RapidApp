package RapidApp::DBIC::AuditAny::AuditContext::Change;
use Moose;
extends 'RapidApp::DBIC::AuditAny::AuditContext';

use RapidApp::Include qw(sugar perlutil);

# ***** PRIVATE Object Class *****

has 'SourceContext', is => 'ro', required => 1;
has 'Row', is => 'ro', required => 1;
#has 'txn_id', is => 'ro', isa => 'Maybe[Str]', default => undef;

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

has 'change_ts', is => 'rw', isa => 'Maybe[DateTime]', default => undef;



# whether or not to fetch the row from storage again after the action
# to identify changes
has 'new_columns_from_storage', is => 'ro', isa => 'Bool', default => 1;

has 'origRow', is => 'ro', init_arg => undef, lazy_build => 1;
sub _build_origRow {
	my $self = shift;
	$self->enforce_unexecuted;
	return $self->Row unless ($self->Row->in_storage);
	return $self->Row->get_from_storage;
}

has 'allowed_actions', is => 'ro', isa => 'ArrayRef', lazy_build => 1;
sub _build_allowed_actions { [qw(insert update delete)] };

has 'action', is => 'rw', init_arg => undef;
has 'executed', is => 'rw', isa => 'Bool', default => 0, init_arg => undef;
has 'dirty_columns', is => 'rw', isa => 'HashRef', default => sub {{}};

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

sub enforce_unexecuted {
	my $self = shift;
	die "Error: Audit action already executed!" if ($self->executed);
}

sub enforce_executed {
	my $self = shift;
	die "Error: Audit action not executed yet!" unless ($self->executed);
}


sub proxy_action {
	my $self = shift;
	my $action = shift;
	my $columns = shift;
	
	die "Bad action '$action'" unless ($action ~~ @{$self->allowed_actions});
	
	$self->enforce_unexecuted;
	$self->origRow;
	$self->action($action);
	$self->executed(1);
	
	$self->Row->set_inflated_columns($columns) if $columns;
	
	$self->dirty_columns({ $self->Row->get_dirty_columns });
	
	$self->change_ts( DateTime->now( time_zone => 'local' ) );
	return $self->Row->$action;
}

sub get_old_columns {
	my $self = shift;
	return () unless ($self->origRow->in_storage);
	return $self->origRow->get_columns;
}

sub get_new_columns {
	my $self = shift;
	return () unless ($self->Row->in_storage);
	my $Row = $self->new_columns_from_storage ? $self->Row->get_from_storage : $self->Row;
	return $Row->get_columns;
}




our $TRY_USE_TABLESPEC = 1;
our $TABLESPEC_EXCLUDE_ORIG_FK_VAL = 0;
has 'column_changes', is => 'ro', isa => 'HashRef[Object]', lazy => 1, default => sub {
	my $self = shift;
	$self->enforce_executed;
	
	my %old = $self->get_old_columns;
	my %new = $self->get_new_columns;
	
	# This logic is duplicated in DbicLink2. Not sure how to avoid it, though,
	# and keep a clean API
	my @changed = ();
	foreach my $col (uniq(keys %new,keys %old)) {
		next if (! defined $new{$col} and ! defined $old{$col});
		next if ($new{$col} eq $old{$col});
		push @changed, $col;
	}
	
	my @new_changed = ();
	
	# Designed to work with proprietary RapidApp/TableSpec, if configured:
	my $use_ts = 1 if ($TRY_USE_TABLESPEC && $self->class->can('TableSpec_get_conf'));
	my $fk_map = $use_ts ? $self->class->TableSpec_get_conf('relationship_column_fks_map') : {};
	
	my %col_context = ();
	my $class = $self->AuditObj->column_context_class;
	foreach my $column (@changed) {
	
		my $col_props = $use_ts ? { $self->class->TableSpec_get_conf('columns') } : {};
		
		my $params = {
			AuditObj => $self->AuditObj,
			ChangeContext => $self,
			column_name => $column, 
			old_value => $old{$column}, 
			new_value => $new{$column},
			col_props => $col_props
		};
				
		my $ColumnContext = $class->new(%$params);
		$col_context{$ColumnContext->column_name} = $ColumnContext;
	}
	
	return \%col_context;
	
	
	
	
	
	
	foreach my $col (@changed) {
		if ($use_ts && $fk_map->{$col}) {
			push @new_changed, $col;
			next;
		}
		
		# ------
		# Only applies to proprietary RapidApp/TableSpec, if present:
		#
		push @new_changed, $col unless ($TABLESPEC_EXCLUDE_ORIG_FK_VAL);
		
		my $rel = $fk_map->{$col};
		my $display_col = $self->class->TableSpec_related_get_set_conf($rel,'display_column');
		
		my $relOld = $self->origRow->$rel;
		my $relNew = $self->Row->$rel;
		
		unless($display_col and ($relOld or $relNew)) {
			push @new_changed, $col if ($TABLESPEC_EXCLUDE_ORIG_FK_VAL);
			next;
		}
		
		push @new_changed, $rel;
		
		$old{$rel} = $relOld->get_column($display_col) if (exists $old{$col} and $relOld);
		$new{$rel} = $relNew->get_column($display_col) if (exists $new{$col} and $relNew);
		#
		# ------
	}
	
	@changed = @new_changed;
	
	my $col_props = $use_ts ? { $self->class->TableSpec_get_conf('columns') } : {};
	my $class = $self->AuditObj->column_context_class;
	return { map { $_ => $class->new({
		AuditObj => $self->AuditObj,
		ChangeContext => $self,
		column_name => $_, 
		old_value => $old{$_}, 
		new_value => $new{$_},
		col_props => ($col_props->{$_} || {})
	}) } @changed };
};




has 'column_datapoint_values', is => 'ro', isa => 'HashRef', lazy => 1, default => sub {
	my $self = shift;
	my @Contexts = values %{$self->column_changes};
	return { map { $_->column_name => $_->datapoint_values } @Contexts };
};



1;