package RapidApp::Column;
use strict;
use warnings;
use RapidApp::Util qw(:all);

our @gridColParams= qw(
  name sortable hidden header dataIndex width editor menuDisabled tpl xtype
  id no_column no_multifilter no_quick_search extra_meta_data css listeners
  filter field_cnf rel_combo_field_cnf field_cmp_config render_fn renderer
  allow_add allow_edit allow_view query_id_use_column query_search_use_column
  trueText falseText menu_select_editor render_column multifilter_type summary_functions
  no_summary allow_batchedit format align is_nullable
);
our @attrs= ( @gridColParams, qw(
  data_type required_fetch_columns read_raw_munger update_munger 
  field_readonly field_readonly_config field_config no_fetch broad_data_type
  quick_search_exact_only enum_value_hash search_operator_strf
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
			
			$val_to_disp{$sel->{value}} = '<img src="assets/rapidapp/misc/static/s.gif" class="ra-icon-centered-16x16 ' . $sel->{iconCls} . '">'
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
	
	# If there is already a 'value' property set in editor save it to preserve it (see below):
	my $orig_value = ref($self->{editor}) eq 'HASH' ? $self->{editor}->{value} : undef;
	
  # Update: removed extra, not-needed check of 'allow_edit' param (fixes Github Issue #35)

  my $mode = $new->{mode} || 'combo';
  
  if($mode eq 'combo') {
    $self->{editor} = {
      xtype => 'ra-icon-combo',
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
  
  # restore the original 'value' if it was already defined (see above)
  $self->{editor}->{value} = $orig_value if (defined $orig_value);
  
  $self->{editor}->{width} = $new->{width} if ($new->{width});
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
		#use Data::Dumper;
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
		#use Data::Dumper;
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

1;