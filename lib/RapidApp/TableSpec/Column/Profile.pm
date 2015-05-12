package RapidApp::TableSpec::Column::Profile;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(get_set); 

use RapidApp::Util qw(:all);

# Base profiles are applied to all columns
sub DEFAULT_BASE_PROFILES {(
  'BASE'
)}


our @number_summary_funcs = (
  { function => 'sum', title => 'Total' },
  { function => 'max', title => 'Max Val' },
  { function => 'min', title => 'Min Val' },
  { function => 'count(distinct({x}))', title => 'Count Unique' },
  { function => 'count', title => 'Count (Set)' },
);

our @text_summary_funcs = (
  { function => 'count(distinct({x}))', title => 'Count Unique' },
  { function => 'count', title => 'Count (Set)' },
  #{ function => 'max(length({x})', title => 'Longest' },
);

our @date_summary_funcs = (
  @number_summary_funcs,
  @text_summary_funcs,
  #{ function => 'CONCAT(DATEDIFF(NOW(),avg({x})),\' days\')', title => 'Ave Age (days)' }, #<-- doesn't work
  { function => 'CONCAT(DATEDIFF(NOW(),min({x})),\' days\')', title => 'Oldest (days)' },
  { function => 'CONCAT(DATEDIFF(NOW(),max({x})),\' days\')', title => 'Youngest (days)' },
  { function => 'CONCAT(DATEDIFF(max({x}),min({x})),\' days\')', title => 'Age Range (days)' }
);

push @number_summary_funcs, (
  { function => 'round(avg({x}),2)', title => 'Average' },
);

# Default named column profiles. Column properties will be merged
# with the definitions below if supplied by name in the property 'profiles'
sub DEFAULT_PROFILES {{
  
  BASE => {
    broad_data_type => 'text',
    is_nullable => 1, #<-- initial/default
    renderer => ['Ext.ux.showNull'] ,
    editor => { xtype => 'textfield', minWidth => 80, minHeight => 22 },
    summary_functions => \@text_summary_funcs
  },
  
  relcol => {
    width => 175
  },
  
  nullable => {
    is_nullable => 1, #<-- redundant/default
    editor => { allowBlank => \1, plugins => [ 'emptytonull' ] }
  },
  
  notnull => {
    is_nullable => 0,
    editor => { allowBlank => \0, plugins => [ 'nulltoempty' ] }
  },
  
  number => {
    broad_data_type => 'number',
    editor => { xtype => 'numberfield', style => 'text-align:left;' },
    multifilter_type => 'number',
    summary_functions => \@number_summary_funcs
  },
  int => {
    broad_data_type => 'integer',
    editor => { xtype => 'numberfield', style => 'text-align:left;', allowDecimals => \0 },
  },
  
  bool => {
    menu_select_editor => {
    
      #mode: 'combo', 'menu' or 'cycle':
      mode => 'menu',
    
      render_icon_only => 1,
    
      selections => [
        {
          iconCls => "ra-icon-cross-light-12x12",
          #iconCls => "ra-icon-cross-tiny",
          text	=> 'No',
          value	=> 0
        },
        {
          iconCls => "ra-icon-checkmark-12x12",
          #iconCls => "ra-icon-tick-tiny",
          text	=> 'Yes',
          value	=> 1
        }
      ]
    },
    
    # piggy-back on the existing quick-search pre-validation for
    # enum columns -- Github issue #60
    enum_value_hash => { '0'=>1,'1'=>1 },
    
    multifilter_type => 'bool'
  },
  
  bool_old => {
    # Renderer *not* in arrayref makes it replace instead of append previous
    # profiles with th renderer property as an arrayref
    renderer => 'Ext.ux.RapidApp.boolCheckMark',
    xtype => 'booleancolumn',
    #trueText => '1',
    #falseText => '0',
    editor => { xtype => 'checkbox'  }
    #editor => { xtype => 'logical-checkbox', plugins => [ 'booltoint' ] }
  },
  text => {
    width => 100,
    editor => { xtype => 'textfield', grow => \0 },
    summary_functions => \@text_summary_funcs 
  },
  bigtext => {
    width => 150,
    renderer 	=> ['Ext.ux.RapidApp.nl2brWrap'],
    editor		=> { xtype => 'textarea', grow => \1 },
    summary_functions => \@text_summary_funcs 
  },
  monotext => {
    width => 150,
    renderer 	=> ['Ext.ux.RapidApp.renderMonoText'],
    editor		=> { xtype => 'textarea', grow => \1 },
    summary_functions => \@text_summary_funcs 
  },
  blob => {
    width    => 130,
    renderer => 'Ext.ux.RapidApp.renderHex',
    # Here we have a (simple) hex editor which works, however, we're still disabling 
    # editing out of the gate as the default because there are so many 
    # possible scenarios for binary data, and in most cases hex editing isn't
    # useful. However, we still have this as the editor, so that if the user
    # *does* want to edit, and manually sets allow_edit to true, the default editor
    # be a sane choice (hex) which will match the default renderer.
    editor     => { xtype => 'ra-hexfield', grow => \1 },
    allow_edit => \0
  },
  html => {
    width => 200,
    # We need this renderer in case the 'bigtext' profile above has been applied
    # automatically. For HTML we *don't* want to nl2br() as it will totally break markup
    renderer => 'Ext.ux.showNull',
    editor => {
      xtype		=> 'ra-htmleditor',
      resizable => \1, #<-- Specific to Ext.ux.RapidApp.HtmlEditor ('ra-htmleditor')
      #height => 200,
      minHeight => 200,
      minWidth	=> 400,
      anchor => '-25',
    },
  },
  email => {
    width => 100,
    editor => { xtype => 'textfield', vtype => 'email' },
    summary_functions => \@text_summary_funcs,
  },
  datetime => {
    # We now disable quick search by default for datetime/date columns because
    # it is more trouble than it is worth. Very rarely would it actually be useful,
    # since the user can still use MultiFilter where they can do things like
    # a relative search. Also, certain databases (PostgreSQL) throw exceptions
    # when querying a datetime column with an invalid datetime string, so, properly
    # supporting this will require server-side validation, which mary vary from
    # backend to backend, etc. TODO: we may look at adding this support in the
    # future using DBIx::Introspector.
    # Note: the user is still free to manually change 'no_quick_search' if they
    # really want it - this is just the default...
    no_quick_search => \1,
    editor => { 
      xtype => 'xdatetime2', 
      plugins => ['form-relative-datetime'], 
      minWidth => 200,
      editable => \0  #<-- force whole-field click/select
    },
    width => 130,
    renderer => ["Ext.ux.RapidApp.getDateFormatter('M d, Y g:i A')"],
    multifilter_type => 'datetime',
    summary_functions => \@date_summary_funcs
  },
  date => {
    # See comment above in the datetime section...
    no_quick_search => \1,
    editor => { 
      xtype => 'datefield', 
      plugins => ['form-relative-datetime'], 
      minWidth => 120,
      editable => \0 #<-- force whole-field click/select
    },
    width => 80,
    renderer => ["Ext.ux.RapidApp.getDateFormatter('M d, Y')"],
    multifilter_type => 'date',
    summary_functions => \@date_summary_funcs
  },
  otherdate => { 
    # for other general 'date' columns that we have no special handling for yet,
    # like 'year' in postgres
    no_quick_search => \1,
  },
  money => {
    editor => { xtype => 'numberfield', style => 'text-align:left;', decimalPrecision => 2 },
    renderer => 'Ext.ux.showNullusMoney',
    summary_functions => \@number_summary_funcs
  },
  percent => {
     editor => { xtype => 'numberfield', style => 'text-align:left;' },
     renderer => ['Ext.ux.RapidApp.num2pct'],
     summary_functions => \@number_summary_funcs
  },
  noadd => {
    allow_add => \0,
  },
  noedit => {
    editor => '',
    allow_edit => \0,
    allow_batchedit => \0
  },
  zipcode => {
    editor => { vtype => 'zipcode' }
  },
  filesize => {
    renderer => 'Ext.util.Format.fileSize',
  },
  autoinc => {
    allow_add => \0,
    allow_edit => \0,
    allow_batchedit => \0
  },
  img_blob => {
    width => 120,
    renderer => "Ext.ux.RapidApp.getEmbeddedImgRenderer()"
  },
  virtual_source => {
    allow_add => \0,
    allow_edit => \0,
    allow_batchedit => \0
  },
  unsearchable => {
    # This profile is for data types for which we do not yet properly support searching on,
    # like PostgreSQL 'tsvector' and array columns...
    no_quick_search => \1,
    no_multifilter => \1
  },
  cas_link => {
    editor   => { xtype => 'cas-upload-field' },
    renderer => 'Ext.ux.RapidApp.renderCasLink'
  },
  soft_rel => {
    # This currently applies only to single rels pointing at sources 
    # auto_editor_type set to 'combo' or 'dropdown'
    auto_editor_params => { user_editable => 1 }
  },
  hidden => {
    no_column => \1, no_quick_search => \1, no_multifilter => \1
  }

}};


our $SKIP_BASE = 0;

# Cache collapsed profile sets process-wide for performance:
my %Sets = ();
sub get_set {
  my @profiles = $SKIP_BASE ? uniq(@_) : uniq(&DEFAULT_BASE_PROFILES(),@_);
  my $key = join('|',@profiles);
  unless (exists $Sets{$key}) {
    my $profile_defs = &DEFAULT_PROFILES();
    my $collapsed = {};
    foreach my $profile (@profiles) {
      my $opt = $profile_defs->{$profile} or next;
      $collapsed = merge($collapsed,$opt);
    }
    $Sets{$key} = $collapsed;
  }
  return $Sets{$key};
}

# One-off function to apply profiles to an arbitrary hashref w/o considering
# the base profile(s) and w/o overriding any existing params. This was added
# for GitHub #77 -- see special invocation in RapidApp::TableSpec::Role::DBIC
sub _apply_profiles_soft {
  shift if ($_[0] && $_[0] eq __PACKAGE__); #<-- support calling as class method
  my ($cnf,@profiles) = @_;
  
  die "apply_profiles(): first argument must be a HashRef" unless ($cnf && ref($cnf) eq 'HASH');
  
  @profiles = @{$cnf->{profiles}} if (
    scalar(@profiles) == 0
    && $cnf->{profiles}
    && ref($cnf->{profiles}) eq 'ARRAY'
  );
  
  die "No profiles supplied" unless (scalar(@profiles) > 0);
  
  local $SKIP_BASE = 1;
  $cnf = merge( clone(&get_set(@profiles)) ,$cnf)
}


1;


__END__

=head1 NAME

RapidApp::TableSpec::Column::Profile - TableSpec Column Profile Definitions

=head1 DESCRIPTION

This class conatins the TableSpec column profile defintions. This class is used
internally and should not be called directly. See L<RapidApp::Manual::TableSpec> 
for more info

=head1 SEE ALSO

=over

=item *

L<RapidApp::Manual::TableSpec>

=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
