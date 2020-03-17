package RapidApp::Module::AppDV;

use strict;
use warnings;

# ABSTRACT: Editable DataView class

use Moose;
extends 'RapidApp::Module::StorCmp';

use RapidApp::Util qw(:all);

use Template;
use RapidApp::Module::AppDV::TTController;

use HTML::TokeParser::Simple;

# If true, the template will refresh itself (client-side) after saving to the store.
# This will make the whole template refresh instead of just the updated rows. This
# is useful when updates involve changes to more than one row/data-point on the backend
has 'refresh_on_save', is => 'ro', isa => 'Bool', default => 0, traits => ['ExtProp'];

# Only makes sense when there is exactly one row; will beging editing the *first* record
# as soon as the page/data is loaded. It is the developer's responsibility to
# include [% r.toggle.edit %] someplace in the template so the user can actually
# save the changes. If the toggle control is not included, or it is otherwise not
# possible for the user to have manually started the edit, this setting will do nothing.
has 'init_record_editable', is => 'ro', isa => 'Bool', default => 0, traits => ['ExtProp'];

# If true, the template will refresh itself (client-side) when the window.location.hash
# changes. Within templates, the value of the hash (without '#') is available as:
#   {[this.hashval]}
has 'refresh_on_hash_change', is => 'ro', isa => 'Bool', default => 0, traits => ['ExtProp'];

# If true, the content will be parsed for a <title> tag to set on the tab in
# the same manner as this works on the JavaScript side for plain html content
has 'parse_html_tabTitle', is => 'ro', isa => 'Bool', default => 1;

# If true, every call to [% r.autofield.<COLUMN> %] will produce an editable control
# instead of just the first one:
has 'multi_editable_autofield', is => 'ro', isa => 'Bool', default => 0;

has 'apply_css_restrict' => ( is => 'ro', default => 0 );

has 'extra_tt_vars' => (
  is => 'ro',
  isa => 'HashRef',
  default => sub {{}}
);


has 'TTController'  => (
  is => 'ro',
  isa => 'RapidApp::Module::AppDV::TTController',
  lazy => 1,
  default => sub {
    my $self = shift;
    return RapidApp::Module::AppDV::TTController->new( AppDV => $self );
  }
);

has 'tt_include_path' => (
  is => 'ro',
  isa => 'Str',
  lazy => 1,
  default => sub {
    my $self = shift;
    return $self->app->default_tt_include_path;
  }
);

has 'tt_file' => ( is => 'ro', isa => 'Str', required => 1 );
sub _tt_file { (shift)->tt_file }

has 'submodule_config_override' => (
  is        => 'ro',
  isa       => 'HashRef[HashRef]',
  default   => sub { {} }
);

has '+DataStore_build_params' => ( default => sub {{
  store_autoLoad => \1
}});

# persist_on_add is AppDV specific, and causes a store save to happen *after* a
# new record has been added via filling out fields. when persist_immediately.create
# is set empty records are instantly created without giving the user the chance
# set the initial values
has 'persist_on_add' => ( is => 'ro', isa => 'Bool', default => 1 );
has '+persist_immediately' => ( default => sub {{
  create  => \0,
  update  => \1,
  destroy  => \1
}});

sub BUILD {
  my $self = shift;

  $self->apply_extconfig(
    xtype        => 'appdv',
    autoHeight    => \1,
    multiSelect    => \1,
    simpleSelect  => \0,
    overClass    => 'record-over',
    persist_on_add  => \scalar($self->persist_on_add),
    items => []
  );

  $self->add_plugin( 'ra-link-click-catcher' );

  #$self->add_listener( afterrender  => 'Ext.ux.RapidApp.AppDV.afterrender_handler' );
  #$self->add_listener(  click     => 'Ext.ux.RapidApp.AppDV.click_handler' );

}

before 'content' => sub {
  my $self = shift;
  $self->load_xtemplate;
};

sub load_xtemplate {
  my $self = shift;
  $self->apply_extconfig( id => $self->instance_id );
  $self->apply_extconfig( tpl => $self->xtemplate );
  $self->apply_extconfig( FieldCmp_cnf => $self->FieldCmp );
  $self->apply_extconfig( items => [ values %{ $self->DVitems } ] );

  my $params = $self->c->req->params;
  my @qry = ();
  foreach my $p (keys %$params) {
    push @qry, $p . '=' . $params->{$p};
  }

  my $qry_str = join('&',@qry);

  $self->apply_extconfig( printview_url => $self->suburl('printview') . '?' . $qry_str );
}


sub xtemplate_cnf_classes {
  my $self = shift;

  #TODO: make this more robust/better:  
  my @classes = ();

  push @classes, 'no_create' unless ($self->DataStore->create_handler);
  push @classes, 'no_update' unless ($self->DataStore->update_handler);
  push @classes, 'no_destroy' unless ($self->DataStore->destroy_handler);
  
  my $excl = $self->get_extconfig_param('store_exclude_api') || [];
  push @classes, 'no_' . $_ for (@$excl);
  
  return uniq @classes;
}

sub xtemplate_cnf {
  my $self = shift;

  my $html_out = '';

  my $tt_vars = {
    c  => $self->c,
    r  => $self->TTController,
    %{ $self->extra_tt_vars }
  };

  my $tt_file = $self->_tt_file;

  {
    local $self->{_template_process_ctx} = {};
    my $Template = Template->new({ INCLUDE_PATH => $self->tt_include_path });
    $Template->process($tt_file,$tt_vars,\$html_out)
      or die $Template->error . "  Template file: $tt_file";
  }

  $self->_parse_html_set_tabTitle(\$html_out) if ($self->parse_html_tabTitle);

  return $html_out unless ($self->apply_css_restrict);

  return '<div class="' . join(' ',$self->xtemplate_cnf_classes) . '">' . $html_out . '</div>';
}



sub xtemplate {
  my $self = shift;

  return RapidApp::JSONFunc->new(
    #func => 'new Ext.XTemplate',
    func => 'Ext.ux.RapidApp.newXTemplate',
    parm => [ $self->xtemplate_cnf, $self->xtemplate_funcs ]
  );
}


# The 'renderField' function defined here is called by 'autofield' in TTController
# This is needed because complex logic can't be called directly within {[ ... ]} in
# XTemplates; only function calls. This function accepts a function as an argument
# (which is allowed) and then calls it in the format and with the arguments expected
# from a Column renderer:
sub xtemplate_funcs {
  my $self = shift;
  return {
    compiled => \1,
    disableFormats => \1,
    renderField => RapidApp::JSONFunc->new( raw => 1, func =>
      'function(name,values,renderer) {' .
        #'var record = { data: values };' .
        #'return renderer(values[name],{},record);' .
        'var dsp = this.store.datastore_plus_plugin;'.
        'var record = this.store.getById(values.___record_pk);' .
        'var args = [values[name],{},record];' .
        'return dsp._masterColumnRender(' .
          '{ renderer: renderer, args: args, name: name }'.
        ');'.
      '}'
    )
  };
}


sub _parse_html_set_tabTitle {
  my ($self, $htmlref) = @_;

  my $parser = HTML::TokeParser::Simple->new($htmlref);

  while (my $token = $parser->get_token) {
    if($token->is_start_tag('title')) {
      my %cnf = ();
      if(my $cls = $token->get_attr('class')) {
        $cnf{tabIconCls} = $cls;
      }
      while (my $inToken = $parser->get_token) {
        last if $inToken->is_end_tag('title');
        my $inner = $inToken->as_is or next;
        $cnf{tabTitle} ||= '';
        $cnf{tabTitle} .= $inner;
      }
      $self->apply_extconfig( %cnf ) if (scalar(keys %cnf) > 0);
    }
  }
}



has 'DVitems' => (
  is => 'ro',
  traits => [ 'RapidApp::Role::PerRequestBuildDefReset' ],
  isa => 'HashRef',
  default => sub {{}}
);

has 'FieldCmp' => (
  is => 'ro',
  traits => [ 'RapidApp::Role::PerRequestBuildDefReset' ],
  isa => 'HashRef',
  default => sub {{}}
);





# Dummy read_records:
sub read_records {
  my $self = shift;

  return {
    results => 1,
    rows => [{ $self->record_pk => 1 }]
  };
}


# This code is not yet fully working. It attemps to process an Ext.XTemplate with TT
sub render_xtemplate_with_tt {
  my $self = shift;
  my $xtemplate = shift;

  #return $xtemplate;

  my $parser = HTML::TokeParser::Simple->new(\$xtemplate);

  my $start = '';
  my $inner = '';
  my $end = '';

  while (my $token = $parser->get_token) {
    unless ($token->is_start_tag('tpl')) {
      $start .= $token->as_is;
      next;
    }
    while (my $inToken = $parser->get_token) {
      last if $inToken->is_end_tag('tpl');

      $inner .= $inToken->as_is;


      if ($inToken->is_start_tag('div')) {
        my $class = $inToken->get_attr('class');
        my ($junk,$submod) = split(/appdv-submodule\s+/,$class);
        if ($submod) {
          my $Module = $self->Module($submod);
        }

      }
    }
    while (my $enToken = $parser->get_token) {
      $end .= $enToken->as_is;
    }
    last;
  }

  #$self->c->scream([$start,$inner,$end]);

  my $tpl = '{ FOREACH rows }' . $inner . '{ END }';

  my $html_out = '';
  my $Template = Template->new({
    START_TAG  => /\{/,
    END_TAG    => /\}/
  });

  my $data = $self->DataStore->read;

  #$self->c->scream($data,$tpl);

  $Template->process(\$tpl,$data,\$html_out)
    or die "Template error (" . $Template->error . ')' .
    "\n\n" .
    "  Template vars:\n" . Dumper($data) . "\n\n" .
    "  Template contents:\n" . Dumper($tpl);

  return $start . $html_out . $end;
}

sub is_printview {
  my $self = shift;
  return 1 if ($self->c->req->header('X-RapidApp-View') eq 'print');
  return 0;
}

# Available to derived classes. Can be added to toolbar buttons, etc
sub print_view_button {
  my $self = shift;
  
  my $params = $self->c->req->params;
  delete $params->{_dc};
  
  my $cnf = {
    url => $self->suburl('printview'),
    params => $params
  };
  
  my $json = $self->json->encode($cnf);
  
  return {
    xtype  => 'button',
    text => 'Print View',
    iconCls => 'ra-icon-printer',
    handler => jsfunc 'Ext.ux.RapidApp.winLoadUrlGET.createCallback(' . $json . ')'
  };
}


1;

__END__

=head1 NAME

RapidApp::Module::AppDV - General-purpose DataView module

=head1 DESCRIPTION

This module provides an interface to render a DataStore-driven module via an C<Ext.DataView>,
including in-line edit capability. It is like a free-form version of L<RapidApp::Module::Grid>.

This module is very complex and is still poorly documented. If you want a custom row page, you
want L<RapidApp::Module::DbicRowDV>


=head1 SEE ALSO

=over

=item *

L<RapidApp>

=item *

L<RapidApp::Manual::Modules>

=item *

L<RapidApp::Module::DbicRowDV>

=back

=head1 AUTHOR

Henry Van Styn <vanstyn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by IntelliTree Solutions llc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut



