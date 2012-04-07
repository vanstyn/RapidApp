package RapidApp::Column;
use strict;
use warnings;
use RapidApp::Include qw(sugar perlutil);

our @gridColParams= qw(
	name sortable hidden header dataIndex width editor menuDisabled tpl xtype
	id no_column no_multifilter no_quick_search extra_meta_data css listeners
	filter field_cnf rel_combo_field_cnf field_cmp_config render_fn renderer
	allow_add allow_edit allow_view query_id_use_column query_search_use_column
	trueText falseText menu_select_editor render_column multifilter_type summary_functions
	no_summary allow_batchedit
);
our @attrs= ( @gridColParams, qw(
	data_type required_fetch_columns read_raw_munger update_munger 
	field_readonly field_readonly_config field_config no_fetch 
) );
our %triggers= (
	render_fn				=> '_set_render_fn',
	renderer  				=> '_set_renderer',
	menu_select_editor	=> '_set_menu_select_editor',
	allow_edit				=> '_set_allow_edit'
);


eval('sub '.$_.' {'
	.(exists($triggers{$_})
		? 'if (scalar @_ > 1) { my $old= $_[0]->{'.$_.'}; $_[0]->{'.$_.'} = $_[1]; $_[0]->'.$triggers{$_}.'($_[0]->{'.$_.'}, $old); }'
		: '$_[0]->{'.$_.'} = $_[1] if scalar @_ > 1;'
	).'$_[0]->{'.$_.'}
}') for @attrs;

our %defaults= (
	sortable               => '\1',
	hidden                 => '\0',
	header                 => '$self->{name}',
	dataIndex              => '$self->{name}',
	width                  => '70',
	no_column              => '\0',
	no_multifilter         => '\0',
	no_quick_search        => '\0',
	field_readonly         => '0',
	required_fetch_columns => '[]',
	field_readonly_config  => '{}',
	field_config           => '{}',
);

eval 'sub apply_defaults {
	my $self= shift;
	'.join(';', map { 'exists $self->{'.$_.'} or $self->{'.$_.'}= '.$defaults{$_} } keys %defaults).'
}';

sub _set_render_fn {
	my ($self,$new,$old) = @_;
	
	die 'render_fn is depricated, please use renderer instead.';
	
	return unless ($new);
	
	# renderer takes priority over render_fn
	return if (defined $self->renderer);
	
	$self->xtype('templatecolumn');
	$self->tpl('{[' . $new . '(values.' . $self->name . ',values)]}');
}

sub _set_renderer {
	my ($self,$new,$old) = @_;
	return unless ($new);
	
	$self->xtype(undef);
	$self->tpl(undef);
	
	return unless (defined $new and not blessed $new);
	$self->{renderer}= jsfunc($new);
}

sub _set_menu_select_editor {
	my ($self,$new,$old) = @_;
	return unless ($new);
	
	my %val_to_disp = ();
	my @value_list = ();
	
	foreach my $sel (uniq(@{$new->{selections}})) {
		push @value_list, [$sel->{value},$sel->{text},$sel->{iconCls}];
		if(defined $sel->{value} and defined $sel->{text}) {
			$val_to_disp{$sel->{value}} = $sel->{text};

			$val_to_disp{$sel->{value}} = '<div class="with-icon ' . $sel->{iconCls} . '">' . $sel->{text} . '</div>'
				if($sel->{iconCls});
				
			$val_to_disp{$sel->{value}} = '<img src="/static/ext/resources/images/default/s.gif" class="icon-centered-16x16 ' . $sel->{iconCls} . '">'
				if($sel->{iconCls} and jstrue($new->{render_icon_only}));
		};
	}
	
	my $first_val;
	$first_val = $value_list[0]->[0] if (defined $value_list[0]);
	
	my $mapjs = encode_json(\%val_to_disp);
	
	my $js = 'function(v){' .
		'var val_map = ' . $mapjs . ';' .
		'if(typeof val_map[v] !== "undefined") { return val_map[v]; }' .
		'return v;' .
	'}';
	
	$self->{renderer} = jsfunc($js,$self->{renderer});
	
	unless (defined $self->{allow_edit} and !jstrue($self->{allow_edit})) {
	
		my $mode = $new->{mode} || 'combo';
		
		if($mode eq 'combo') {
			$self->{editor} = {
				xtype => 'icon-combo',
				allowBlank => \0,
				value_list => \@value_list,
			};
		}
		elsif($mode eq 'menu') {
		
			$self->{editor} = {
				xtype => 'menu-field',
				menuOnShow => \1,
				value_list => \@value_list,
				value => $first_val,
				minHeight => 10,
				minWidth => 10
			};
			
			$self->{editor}->{header} = $new->{header} || $self->header;
			delete $self->{editor}->{header} unless (
				defined $self->{editor}->{header} and
				$self->{editor}->{header} ne ''
			);
		
		}
		elsif($mode eq 'cycle') {
		
			$self->{editor} = {
				xtype => 'cycle-field',
				cycleOnShow => \1,
				value_list => \@value_list,
				value => $first_val,
				minHeight => 10,
				minWidth => 10
			};
		
		}
		else {
			die "menu_select_editor: Invalid mode '$mode' - must be 'combo', 'menu' or 'cycle'"
		}
		
		$self->{editor}->{width} = $new->{width} if ($new->{width});
	}
}

sub _set_allow_edit {
	my ($self,$new,$old) = @_;
	return unless (defined $new);
	
	# This line is still causing issues, removed for now
	#$self->{editor} = '' if(!jstrue($new) and defined $self->{editor} and !jstrue($self->allow_add));
}

our %attrKeySet= map { $_ => 1 } @attrs;
our %gridColParamKeySet= map { $_ => 1 } @gridColParams;

sub new {
	my $class= shift;
	my $self= bless { (ref($_[0]) eq 'HASH')? %{$_[0]} : @_ }, $class;
	$self->{renderer} = jsfunc($self->{renderer}) if (defined $self->{renderer} and not blessed $self->{renderer});
	for (keys %$self) {
		$attrKeySet{$_} || die("No such attribute: $class\::$_");
		my $t= $triggers{$_};
		$t and $self->$t($self->{$_});
	}
	$self->apply_defaults;
	return $self;
}

sub apply_attributes {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $attr (@attrs) {
		next unless (exists $new{$attr});
		$self->$attr($new{$attr});
		delete $new{$attr};
	}
	
	#There should be nothing left over in %new:
	if (scalar(keys %new) > 0) {
		#die "invalid attributes (" . join(',',keys %new) . ") passed to apply_attributes";
		use Data::Dumper;
		die  "invalid attributes (" . join(',',keys %new) . ") passed to apply_attributes :\n" . Dumper(\%new);
	}
}

sub applyIf_attributes {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $attr (@attrs) {
		next unless (exists $new{$attr});
		$self->$attr($new{$attr}) unless defined $self->{$attr}; # <-- only set attrs that aren't already set
		delete $new{$attr};
	}
	
	#There should be nothing left over in %new:
	if (scalar(keys %new) > 0) {
		#die "invalid attributes (" . join(',',keys %new) . ") passed to apply_attributes";
		use Data::Dumper;
		die  "invalid attributes (" . join(',',keys %new) . ") passed to apply_attributes :\n" . Dumper(\%new);
	}
}

sub get_grid_config {
	my $self = shift;
	return { map { defined($self->{$_})? ($_ => $self->{$_}) : () } @gridColParams };
}

sub apply_field_readonly_config	{
	my $self= shift;
	%{ $self->{field_readonly_config} }= %{ $self->{field_readonly_config} }, (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
}

sub get_field_config_readonly_param {
	my $self= shift;
	return $self->{field_readonly_config}{$_[0]};
}

sub has_field_config_readonly_param	{
	my $self= shift;
	return exists $self->{field_readonly_config}{$_[0]};
}

sub has_no_field_readonly_config {
	my $self= shift;
	return 0 == (keys %{ $self->{field_readonly_config} });
}

sub delete_field_readonly_config_param {
	my $self= shift;
	delete $self->{field_readonly_config}{$_[0]};
}

sub apply_field_config {
	my $self= shift;
	%{ $self->{field_config} }= %{ $self->{field_config} }, (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
}
sub get_field_config_param {
	my $self= shift;
	return $self->{field_config}{$_[0]};
}

sub has_field_config_param	{
	my $self= shift;
	return exists $self->{field_config}{$_[0]};
}
sub has_no_field_config {
	my $self= shift;
	return 0 == (keys %{ $self->{field_config} });
}

sub delete_field_config_param {
	my $self= shift;
	delete $self->{field_config}{$_[0]};
}

sub get_field_config {
	my $self = shift;
	
	my $config = $self->field_config;
	$config = $self->editor if ($self->editor);
	
	my $cnf = { 
		name		=> $self->name,
		%$config
	};
	
	$cnf = { %$cnf, %{$self->field_readonly_config} } if ($self->field_readonly);
	
	$self->field_cmp_config($cnf);
	
	return $cnf;
}

=pod

# We extend the metaclass here to hold a list of attributes which are "grid config" parameters.
# Note that to properly handle dynamic package modifications we would need to  invalidate this cache in many
#    circumstances, which would add a lot of complexity to this class.
# As long as we define attributes at compile-time, and call grid_config_attr_names at runtime, we can keep things simple.
package RapidApp::Column::Meta::Class;
use Moose;
BEGIN {
	extends 'Moose::Meta::Class';
	
	has '_grid_config_attr_names' => ( is => 'ro', isa => 'ArrayRef', lazy_build => 1 );
	sub _build__grid_config_attr_names {
		my $self= shift;
		return [ map { $_->name } grep { $_->does('RapidApp::Role::GridColParam') } $self->get_all_attributes ];
	}
	
	sub grid_config_attr_names { return @{(shift)->_grid_config_attr_names} }
	
	__PACKAGE__->meta->make_immutable;
}

#-----------------------------------------------------------------------
#  And now, for the main package.
#
package RapidApp::Column;

BEGIN{ Moose->init_meta(for_class => __PACKAGE__, metaclass => 'RapidApp::Column::Meta::Class'); }

use Moose;

use RapidApp::Include qw(sugar perlutil);

our $VERSION = '0.1';


has 'name' => ( 
	is => 'ro', required => 1, isa => 'Str', 
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'sortable' => ( 
	is => 'rw', 
	default => sub {\1},
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'hidden' => ( 
	is => 'rw', 
	default => sub {\0},
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'header' => ( 
	is => 'rw', lazy => 1, isa => 'Str', 
	default => sub { (shift)->name },
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'dataIndex' => ( 
	is => 'rw', lazy => 1, isa => 'Str', 
	default => sub { (shift)->name },
	traits => [ 'RapidApp::Role::GridColParam' ] 
);


has 'width' => ( 
	is => 'rw', lazy => 1, 
	default => 70,
	traits => [ 'RapidApp::Role::GridColParam' ] 
);


has 'editor' => ( 
	is => 'rw', lazy => 1, 
	default => undef,
	traits => [ 'RapidApp::Role::GridColParam' ] 
);


has 'menuDisabled' => ( 
	is => 'rw', lazy => 1, 
	default => undef,
	traits => [ 'RapidApp::Role::GridColParam' ] 
);


has 'tpl' => ( 
	is => 'rw', lazy => 1, 
	default => undef,
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'xtype' => ( 
	is => 'rw', lazy => 1, 
	default => undef,
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'id' => ( 
	is => 'rw', lazy => 1, 
	default => undef,
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'no_column' => ( 
	is => 'rw', 
	default => sub {\0},
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'no_multifilter' => ( 
	is => 'rw', 
	default => sub {\0},
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'no_quick_search' => ( 
	is => 'rw', 
	default => sub {\0},
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'extra_meta_data' => ( 
	is => 'rw', lazy => 1, 
	default => undef,
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'css' => ( 
	is => 'rw', lazy => 1, 
	default => undef,
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'listeners' => ( 
	is => 'rw', lazy => 1, 
	default => undef,
	traits => [ 'RapidApp::Role::GridColParam' ] 
);

has 'data_type'	=> ( is => 'rw', default => undef );

has 'filter'	=> ( is => 'rw', default => undef, traits => [ 'RapidApp::Role::GridColParam' ]  );

has 'field_cnf'	=> ( is => 'rw', default => undef, traits => [ 'RapidApp::Role::GridColParam' ]  );
has 'rel_combo_field_cnf'	=> ( is => 'rw', default => undef, traits => [ 'RapidApp::Role::GridColParam' ]  );

has 'field_cmp_config'	=> ( is => 'rw', default => undef, traits => [ 'RapidApp::Role::GridColParam' ]  );

has 'no_fetch' => ( 
	is => 'rw',
	isa => 'Bool',
	default => 0, 
);

# Optional list of other column names that should be fetched along with this column:
has 'required_fetch_columns' => ( 
	is => 'rw',
	isa => 'ArrayRef',
	default => sub {[]}, 
);

has 'read_raw_munger' => ( 
	is => 'rw',
	isa => 'Maybe[RapidApp::Handler]',
	default => undef, 
);

has 'update_munger' => ( 
	is => 'rw',
	isa => 'Maybe[RapidApp::Handler]',
	default => undef, 
);

has 'render_fn' => ( 
	is => 'rw', lazy => 1, 
	default => undef,
	traits => [ 'RapidApp::Role::GridColParam' ],
	trigger => \&_set_render_fn,
);

sub _set_render_fn {
	my ($self,$new,$old) = @_;
	return unless ($new);
	
	# renderer takes priority over render_fn
	return if (defined $self->renderer);
	
	$self->xtype('templatecolumn');
	$self->tpl('{[' . $new . '(values.' . $self->name . ',values)]}');
}

has 'renderer' => ( 
	is => 'rw', lazy => 1, 
	default => undef,
	traits => [ 'RapidApp::Role::GridColParam' ],
	trigger => \&_set_renderer,
	initializer => sub {
		my ($self, $value, $setter, $attr) = @_;
		$value = jsfunc($value) if (defined $value and not blessed $value);
		$setter->($value);
	},
);

sub _set_renderer {
	my ($self,$new,$old) = @_;
	return unless ($new);
	
	$self->xtype(undef);
	$self->tpl(undef);
	
	return unless (defined $new and not blessed $new);
	my $attr = $self->meta->find_attribute_by_name('renderer') or return;
	$attr->set_value($self,jsfunc($new));
}



sub apply_attributes {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $attr ($self->meta->get_all_attributes) {
		next unless (exists $new{$attr->name});
		$attr->set_value($self,$new{$attr->name});
		delete $new{$attr->name};
	}
	
	#There should be nothing left over in %new:
	if (scalar(keys %new) > 0) {
		#die "invalid attributes (" . join(',',keys %new) . ") passed to apply_attributes";
		use Data::Dumper;
		die  "invalid attributes (" . join(',',keys %new) . ") passed to apply_attributes :\n" . Dumper(\%new);
	}
}

sub applyIf_attributes {
	my $self = shift;
	my %new = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
	
	foreach my $attr ($self->meta->get_all_attributes) {
		next unless (exists $new{$attr->name});
		$attr->set_value($self,$new{$attr->name}) unless ($attr->get_value($self)); # <-- only set attrs that aren't already set
		delete $new{$attr->name};
	}
	
	#There should be nothing left over in %new:
	if (scalar(keys %new) > 0) {
		#die "invalid attributes (" . join(',',keys %new) . ") passed to apply_attributes";
		use Data::Dumper;
		die  "invalid attributes (" . join(',',keys %new) . ") passed to apply_attributes :\n" . Dumper(\%new);
	}
}

sub get_grid_config {
	my $self = shift;
	my $val;
	return { map { defined($val= $self->$_)? ($_ => $val)  :  () } $self->meta->grid_config_attr_names };
	
	#for my $attrName (@{&meta_gridColParam_attr_names($self->meta)}) {
	#	my $val= $self->$attrName();
	#	$config->{$attrName}= $val if defined $val;
	#}
	#return $config
	
	#return $self->get_config_for_traits('RapidApp::Role::GridColParam');
}

# returns hashref for all attributes with defined values that 
# match any of the list of passed traits
sub get_config_for_traits {
	my $self = shift;
	my @traits = @_;
	@traits = @{ $_[0] } if (ref($_[0]) eq 'ARRAY');
	
	my $config = {};
	
	foreach my $attr ($self->meta->get_all_attributes) {
		foreach my $trait (@traits) {
			if ($attr->does($trait)) {
				my $val = $attr->get_value($self);
				last unless (defined $val);
				$config->{$attr->name} = $val;
				last;
			}
		}
	}
		
	return $config;
}

## -- vvv -- new parameters for Forms:
has 'field_readonly' => ( 
	is => 'rw', 
	traits => [ 'RapidApp::Role::PerRequestBuildDefReset' ],
	isa => 'Bool', 
	default => 0 
);

has 'field_readonly_config' => (
	traits    => [ 'Hash' ],
	is        => 'ro',
	isa       => 'HashRef',
	default   => sub { {} },
	handles   => {
		 apply_field_readonly_config			=> 'set',
		 get_field_config_readonly_param		=> 'get',
		 has_field_config_readonly_param		=> 'exists',
		 has_no_field_readonly_config 		=> 'is_empty',
		 delete_field_readonly_config_param	=> 'delete'
	},
);

has 'field_config' => (
	traits    => [ 'Hash' ],
	is        => 'ro',
	isa       => 'HashRef',
	default   => sub { {} },
	handles   => {
		 apply_field_config			=> 'set',
		 get_field_config_param		=> 'get',
		 has_field_config_param		=> 'exists',
		 has_no_field_config 		=> 'is_empty',
		 delete_field_config_param	=> 'delete'
	},
);

sub get_field_config {
	my $self = shift;
	
	my $config = $self->field_config;
	$config = $self->editor if ($self->editor);
	
	my $cnf = { 
		name		=> $self->name,
		%$config
	};
	
	$cnf = { %$cnf, %{$self->field_readonly_config} } if ($self->field_readonly);
	
	$self->field_cmp_config($cnf);
	
	return $cnf;
}
## -- ^^^ --

no Moose;
__PACKAGE__->meta->make_immutable;
=cut
1;
