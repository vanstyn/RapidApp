package RapidApp::DBIC::Component::InputDateTime;
use base 'DBIx::Class';

# DBIx::Class Component: overrides insert/update to convert 
# datetime columns into DateTime objects before they are
# sent to the database

## Note: This Componenet does not appear to be needed for ExtJS dates

use RapidApp::Include qw(sugar perlutil);

use DateTime::Format::Flexible;

use RapidApp::TableSpec;
use RapidApp::DbicAppCombo2;

__PACKAGE__->mk_classdata( 'datetime_column_list' );

sub setup_datetime_columns {
	my $self = shift;
	my $data_types = [ @_ ];
	$data_types = $_[0] if (ref($_[0]) eq 'ARRAY');
	$data_types = [ 'date', 'datetime' ] if (scalar @_ == 0);
	my %types = map { $_ => 1 } @$data_types;
	
	my @list = ();
	
	foreach my $col ($self->columns) {
		my $info = $self->column_info($col);
		next unless ($types{$info->{data_type}});
		push @list, $col;
	}
	
	$self->datetime_column_list(\@list);
}


sub parse_inflate_datetime_columns {
	my $self = shift;
	
	for my $column ( @{ $self->datetime_column_list || [] } ) {
		next unless ($self->has_column($column));
		my $value = $self->get_column($column) or next;
		next if (ref($value));
		my $dt = DateTime::Format::Flexible->parse_datetime($value) or next;
		$self->set_column($column,$dt);
	}
}

sub insert {
	my $self = shift;
	$self->parse_inflate_datetime_columns;
	$self->next::method(@_);
}

sub update {
	my $self = shift;
	my $columns = shift;
	
	$self->set_inflated_columns($columns) if $columns;
	$self->parse_inflate_datetime_columns;
	$self->next::method(@_);
}

1;
