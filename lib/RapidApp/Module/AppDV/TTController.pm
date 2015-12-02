package RapidApp::Module::AppDV::TTController;

use strict;
use warnings;

use Moose;

use RapidApp::Util qw(:all);

use RapidApp::Module::AppDV::RecAutoload;

has 'AppDV' => (
  is => 'ro',
  isa => 'RapidApp::Module::AppDV',
  required => 1
);


sub dataview_id {
  my $self = shift;
  return $self->AppDV->get_extconfig_param('id');
}




sub div_wrapper {
  my ($self,$inner) = @_;
  my @cls = (
    'appdv-tt-generated',$self->dataview_id,
    ( $self->{_div_block} ? 'blk' : () ), 'inln'
  );
  return join('','<div class="',join(' ',@cls),'">',$inner,'</div>');
}




sub div_clickable {
  my $self = shift;
  return $self->div_wrapper(
    '<div class="clickable inln">' . 
      (shift) . 
    '</div>'
  );
}

sub div_clickable_command {
  my $self = shift;
  return $self->div_wrapper(
    '<div class="clickable command inln">' . 
      (shift) . 
    '</div>'
  );
}



sub delete_record {
  my $self = shift;
  return $self->div_clickable('<div class="delete-record">Delete</div>');
}

sub print_view {
  my $self = shift;
  return $self->div_clickable('<div class="print-view">Print View</div>');
}


sub div_editable_value {
  my $self = shift;
  my $name = shift;
  
  my @cls = qw/editable-value inln/;
  push @cls, @{ $self->{_editable_value_extra_classes} || [] };
  
  return $self->div_clickable(
    
    '<div class="'.join(' ',@cls).'">' .
      '<div class="field-name" style="display:none;">' . $name . '</div>' .
      (shift) .
    '</div>'
  );
}

sub data_wrapper_div {
  my $self = shift;
  my $name = shift;
  my $display = shift;
  $display = $name unless ($display);
  
  my $div = '<div class="data-holder inln"';
  
  my $Column = $self->AppDV->get_column($name);
  if($Column) {
    my $style = $Column->get_field_config->{data_wrapper_style};
    $div .= ' style=" ' . $style . '"' if ($style);
  }
  
  return '<div class="data-wrapper">' .
    $div . '>{' . $display . '}</div>' .
    '<div class="field-holder"></div>' .
  '</div>' ;
}



sub div_edit_field {
  my $self = shift;
  my $name = shift;
  my $display = shift;
  $display = $name unless ($display);
  return $self->div_editable_value($name,
    '<div class="appdv-edit-field inln">' .  
        $self->data_wrapper_div($name,$display) . 
                
        '<div class="icons">' .
          '<div class="edit">&nbsp;</div>' .
          '<div class="save" title="save">&nbsp;</div>' .
          '<div class="cancel" title="cancel">&nbsp;</div>' .
        '</div>' .
    '</div>'
  );
}


sub div_edit_field_no_icons {
  my $self = shift;
  my $name = shift;
  my $display = shift;
  $display = $name unless ($display);
  return $self->div_editable_value($name,
    '<div class="appdv-edit-field inln">' .  
        $self->data_wrapper_div($name,$display) . 
        
        '<div class="icons">' . # "no icons" now applies only to save/cancel
          '<div class="edit">&nbsp;</div>' .

        '</div>' .
    '</div>'
  );
}



sub div_bigfield {
  my $self = shift;
  my $name = shift;
  my $display = shift;
  $display = $name unless ($display);
  
  return $self->div_editable_value($name,
    '<div class="appdv-edit-bigfield require-edit-click">' .
      $self->data_wrapper_div($name,$display)  . 
      '<div class="icons">' .
        '<div class="edit">edit</div>' .
        '<div class="pseudo-edit-wrapper"></div>' .
        '<div class="cancel">cancel</div>' .
        '<div class="save">save</div>' .
      '</div>' .
    '</div>'
  );
}



has 'field' => (
  is => 'ro',
  lazy => 1,
  default => sub {
    my $self = shift;
    return RapidApp::Module::AppDV::RecAutoload->new( process_coderef => sub {
      my $name = shift;
      my $Column = $self->AppDV->get_column($name) or return '';
      $self->FieldCmp->{$Column->name} = $self->AppDV->json->encode($Column->get_field_config);
      
      return '<div class="' . $Column->name . '">{' . $Column->name . '}</div>';
    });
  
  }
);



has 'edit_field' => (
  is => 'ro',
  lazy => 1,
  isa => 'RapidApp::Module::AppDV::RecAutoload',
  default => sub {
    my $self = shift;
    return RapidApp::Module::AppDV::RecAutoload->new( process_coderef => sub {
      my $name = shift;
      my $display = shift;
      $display = $name unless ($display);
      my $Column = $self->AppDV->get_column($name) or return '';
      
      $self->AppDV->FieldCmp->{$Column->name} = $self->AppDV->json->encode($Column->get_field_config);

      return $self->div_edit_field($Column->name,$display);
    });
  }
);


has 'edit_bigfield' => (
  is => 'ro',
  lazy => 1,
  isa => 'RapidApp::Module::AppDV::RecAutoload',
  default => sub {
    my $self = shift;
    return RapidApp::Module::AppDV::RecAutoload->new( process_coderef => sub {
      my $name = shift;
      my $display = shift;
      $display = $name unless ($display);
      my $Column = $self->AppDV->get_column($name) or return '';
      
      $self->AppDV->FieldCmp->{$Column->name} = $self->AppDV->json->encode($Column->get_field_config);

      return $self->div_bigfield($Column->name,$display);

    });
  }
);
    
    
has 'edit_click_field' => (
  is => 'ro',
  lazy => 1,
  isa => 'RapidApp::Module::AppDV::RecAutoload',
  default => sub {
    my $self = shift;
    return RapidApp::Module::AppDV::RecAutoload->new( process_coderef => sub {
      my $name = shift;
      my $Column = $self->AppDV->get_column($name) or return '';
      
      $self->AppDV->FieldCmp->{$Column->name} = $self->AppDV->json->encode($Column->get_field_config);


      
      return
      
      '<div class="appdv-click ' . $self->AppDV->get_extconfig_param('id') . '">' .
      

          '<div class="data appdv-editable-value"><span>{' . $Column->name . '}</span></div>' .
          
      '</div>';

    });
  }
);

# Like autofield, but forces read-only
has 'renderfield', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return RapidApp::Module::AppDV::RecAutoload->new( 
    process_coderef => $self->_autofield_processor({ ro => 1 })
  );
}, isa => 'RapidApp::Module::AppDV::RecAutoload';

has 'autofield', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return RapidApp::Module::AppDV::RecAutoload->new( 
    process_coderef => $self->_autofield_processor
  );
}, isa => 'RapidApp::Module::AppDV::RecAutoload';

has 'column_info', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return RapidApp::Module::AppDV::RecAutoload->new( 
    process_coderef => $self->_autofield_processor({ special => 'column_info' })
  );
}, isa => 'RapidApp::Module::AppDV::RecAutoload';

sub _autofield_processor {
  my $self = shift;
  my $cnf = shift || {};
  return sub {
      my $name = shift;
      my $display = shift;
      $display = $name unless ($display);
      my $Column = $self->AppDV->get_column($name) or return '';
      
      if (my $special = $cnf->{special}) {
        return clone( $Column ) if ($special eq 'column_info');
        
        # future use ...
        die "Bad/unknown 'special' code $special";
      }
      
      my $ro = $Column->editor ? 0 : 1;
      
      $ro = 1 if ($cnf->{ro});
      
      $ro = 1 unless ($Column->allow_edit || $Column->allow_add);
      
      # -- Only allow the same column through as editable once per template processing
      if(my $hsh = $self->AppDV->{_template_process_ctx}){
        $ro = 1 if (!$ro && ! $self->AppDV->multi_editable_autofield && $hsh->{seen_fieldnames}{$name}++);
      }
      # --
      
      if($Column->renderer) {
        $display = '[this.renderField("' . $name . '",values,' . $Column->renderer->func . ')]';
      }
      
      local $self->{_div_block} = 0;
      my $config = $Column->get_field_config;
      
      my @block_types = qw(cas-image-field);
      my %block_types = map {$_=>1} @block_types;
      $self->{_div_block} = 1 if($config->{xtype} && $block_types{$config->{xtype}});
      
      # read-only:
      return $self->div_wrapper('{' . $display . '}') if ($ro);
      
      # -- New: add 'no-edit' to the list of css classes that will be applied to the div
      # if this column is non-editable. This only matters when allow_add is true, meaning
      # the column cannot be edited, except when its for a new record. This CSS class is
      # used to distinguish between these cases when allow_edit and allow_add disagree
      my @cls = ();
      push @cls, 'no-edit' unless($Column->allow_edit);
      local $self->{_editable_value_extra_classes} = \@cls;
      # --
      
      # -- TODO: refactor AppDV for all the changes that came with TableSpec
      # in the mean time, this makes sure the editor/field isn't too small
      $config->{minHeight} = 22 unless ($config->{minHeight});
      $config->{minWidth} = $Column->width + 30 if ($Column->width and ! $config->{minWidth});
      # --

      
      ##############
      ### FIX ME ###
      ##############
      
      ## Temp hack workaround ##
      ## for some reason 'checkbox' field doesn't work in AppDV. The checkbox is not clickable.
      ## It is some kind of low-level browser issue
      ## I spent a bunch of time trying to figure it out and then finally have up and wrote
      ## 'logical-checkbox'.  (might be a fundamental flaw in AppDV)
      ## This is ugly and needs to be fixed, as this workaround is "spooky action at a distance"
      $config->{xtype} = 'logical-checkbox' if ($config->{xtype} eq 'checkbox');
      ##
      ##
      
      ##############
      ##############
      ##############
      
      
      
      $self->AppDV->FieldCmp->{$Column->name} = $self->AppDV->json->encode($config);
      
      # editable
      
      my @bigfield_types = qw(textarea htmleditor ra-htmleditor);
      my %bf_types = map {$_=>1} @bigfield_types;
      return $self->div_bigfield($Column->name,$display) if (
        $bf_types{$config->{xtype}}
      );
      
      my @no_icons_types = qw(cycle-field menu-field);
      my %ni_types = map {$_=>1} @no_icons_types;
      return $self->div_edit_field_no_icons($Column->name,$display) if (
        $ni_types{$config->{xtype}}
      );
      
      return $self->div_edit_field($Column->name,$display);
  }
}


has 'store_button', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return RapidApp::Module::AppDV::RecAutoload->new( 
    process_coderef => $self->_store_button_processor
  );
}, isa => 'RapidApp::Module::AppDV::RecAutoload';


sub _store_button_processor {
  my $self = shift;
  
  my @valid = qw/add edit delete reload save undo/;
  my %valid = map {$_=>1} @valid;
  
  my $btnCfgs = $self->AppDV->get_extconfig_param('store_button_cnf') || {};
  return sub {
    my $name = shift;
    my $inner = shift;
    
    die join('',
      "Invalid store button '$name' (must be one of ",
      join(', ',@valid),')'
    ) unless ($valid{$name});
    
    unless($inner) {
      my $cfg = $btnCfgs->{$name} || {};
      my $text = $cfg->{text} || ucfirst($name);
      
      $inner = join('','<div', 
        ($cfg->{iconCls} ? ' class="with-inline-icon '.$cfg->{iconCls}.'"' : ''),
        '>',$text,'</div>'
      );
    }

    return $self->div_clickable_command(join('',
      '<div class="store-button '.$name.'">',$inner,'</div>'
    ));
  }
}
  
    
has 'submodule' => (
  is => 'ro',
  lazy => 1,
  isa => 'RapidApp::Module::AppDV::RecAutoload',
  default => sub {
    my $self = shift;
    return RapidApp::Module::AppDV::RecAutoload->new( process_coderef => sub {
      my $name = shift;
      
      my $Module = $self->AppDV->Module($name) or return '';
      
      return $self->div_module_content($name,$Module);
      
    });
  }
);


sub get_Module {
  my $self = shift;
  my $path = shift;
  
  my $Module = $self->AppDV->get_Module($path) or return '';
  
  $path =~ s/\//\_/g;
      
  return $self->div_module_content($path,$Module);
}

# Example tt usage:
# [% r.ajaxcmp('projects2','/main/explorer/projects2','{"p1":"p1val","p2":"p2val"}') %]
sub ajaxcmp {
  my $self = shift;
  my $name = shift;
  my $url = shift;
  my $params_enc = shift;
  
  my $params = {};
  $params = $self->AppDV->json->decode($params_enc) if (defined $params_enc);
  
  
  my $cnf = {
    xtype   => 'ajaxcmp',
    applyCnf => {
      plugins => [ 'autowidthtoolbars' ],
      autoHeight => \1
    },
    renderTarget => 'div.appdv-submodule.' . $name,
    applyValue => $self->AppDV->record_pk,
    autoLoad  => {
      url    => $url,
      params  => $params
    },
  };
  
  return $self->div_module($name,$cnf);
}


sub div_module_content {
  my $self = shift;
  my $name = shift;
  my $Module = shift;
  
  my $cnf = {
    plugins => [ 'autowidthtoolbars' ],
    autoHeight => \1,
    renderTarget => 'div.appdv-submodule.' . $name,
    applyValue => $self->AppDV->record_pk,
    %{ $Module->content }
  };
  
  return $self->div_module($name,$cnf);
}


sub init_dynamic_ajaxcmp {
  my $self = shift;
  my $target = shift;
  my $name = $target;
  
  $name =~ s/\./\_/g;
  
  my $cnf = {
    renderDynTarget => $target
  };
  
  $self->div_module($name,$cnf);
  return '';
}





sub div_module {
  my $self = shift;
  my $name = shift;
  my $cnf = shift;
  
  # Apply optional overrides:
  $cnf = { %$cnf, %{ $self->AppDV->submodule_config_override->{$name} } } if ($self->AppDV->submodule_config_override->{$name});
  
  # Store component configs as serialized JSON to make sure
  # they come out the same every time on the client side:
  $self->AppDV->DVitems->{$name} = $self->AppDV->json->encode($cnf);
  
  return '<div class="appdv-submodule ' . $name . '"></div>';
}



sub toggle {
  my $self = shift;
  return {
    edit => $self->div_clickable(
      '<div class="edit-record-toggle default inln">' .
        '<div class="edit">Edit</div>' .
        '<div class="save">Save</div>' .
        '<div class="cancel">Cancel</div>' .
      '</div>'
    ),
            
    select  => '<div class="appdv-toggle select"></div>'
  };
}



1;
