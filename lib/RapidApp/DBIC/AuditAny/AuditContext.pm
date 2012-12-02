package RapidApp::DBIC::AuditAny::AuditContext;
use Moose;

use RapidApp::Include qw(sugar perlutil);

# ***** PRIVATE Object Class *****

has 'AuditObj', is => 'ro', isa => 'RapidApp::DBIC::AuditAny', required => 1;
has 'txn_id', is => 'ro', isa => 'Maybe[Str]', default => undef;
has 'Row', is => 'ro', required => 1;

has 'ResultSource', is => 'ro', lazy => 1, default => sub { (shift)->Row->result_source };
has 'source', is => 'ro', lazy => 1, default => sub { (shift)->ResultSource->source_name };
has 'schema', is => 'ro', lazy => 1, default => sub { (shift)->ResultSource->schema };
has 'class', is => 'ro', lazy => 1, default => sub { $_[0]->schema->class($_[0]->source) };

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
sub get_changes {
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
		
	foreach my $col (@changed) {
		unless($use_ts && $fk_map->{$col}) {
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
	
	my %diff = map {
		$_ => { 
			old => $old{$_}, 
			new => $new{$_},
			header => ($col_props->{$_} && $col_props->{$_}->{header}) ? 
				$col_props->{$_}->{header} : $_
		} 
	} @changed;
	
	return \%diff;
}


1;