package RapidApp::AppEdDataView;


use strict;
use Moose;

extends 'RapidApp::AppDataView';

use RapidApp::JSONFunc;


use String::Random;



has 'item_template' => ( is => 'ro', default => '' );


has 'fields' => ( is => 'ro', isa => 'ArrayRef', default => sub {[]} );
has 'field_hash' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	my $h = {};
	foreach my $field (@{$self->fields}) {
		$h->{$field->{name}} = $field;
	}
	return $h;
});

has 'dv_fieldCallbacks' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;
	
	my $callbacks = {};
	
	foreach my $field (@{$self->fields}) {
		if (defined $field->{Callback}) {
			$callbacks->{$field->{name}} = $field->{Callback};
			next;
		}
		$callbacks->{$field->{name}} = $self->defaultCallback($field);
	}
	
	return $callbacks;
});



around 'DataView' => sub {
	my $orig = shift;
	my $self = shift;
	
	my $config = $self->$orig(@_)->parm;
	$config->{fieldCallbacks} = $self->dv_fieldCallbacks;
	
	my $DataView = RapidApp::JSONFunc->new( 
		func => 'new Ext.DataView',
		parm => $config
	);
	
	return $DataView;
};
	

has 'listeners' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;

	my $click = 
		'function(dv, index, htmlEl, event){ ' .
			'dv.getEl().repaint();' .
			'var Record = dv.getStore().getAt(index);';
	
	foreach my $field (@{$self->fields}) {
		$click .= 
			'if (!Ext.isEmpty(event.getTarget("' . $self->fieldTarget($field) . '"))) {' .
				'if (dv.fieldCallbacks["' . $field->{name} . '"]) {' .
					'var callback = dv.fieldCallbacks["' . $field->{name} . '"];' .
					'var field = ' . $self->json->encode($field) . ';' .
					'callback(Record,field);' .
				'}' .
			'}';
	}
	
	$click .= '}';
	
	return { click => RapidApp::JSONFunc->new( raw => 1, func => $click ) };

});

has 'ed_icon' => ( is => 'ro', default =>'<img src="/static/rapidapp/images/pencil_tiny.png">' );

sub fieldMarkup {
	my $self = shift;
	my $field_name = shift;
	my $field = $self->field_hash->{$field_name};
	return $field->{Markup} if (defined $field->{Markup});
	
	my $markup = '{' . $field->{name} . '}';
	$markup .= ' <a href="#" class="' . $field->{name} . '">' . $self->ed_icon . '</a>' if ($field->{editable});
	return $markup;
}

sub fieldLabel {
	my $self = shift;
	my $field_name = shift;
	my $field = $self->field_hash->{$field_name};
	return $field->{label} if (defined $field->{label});
	return $field->{name};
}



sub fieldTarget {
	my $self = shift;
	my $field = shift;
	return $field->{Target} if (defined $field->{Target});
	return 'a.' . $field->{name};
}


sub defaultCallback {
	my $self = shift;
	my $field = shift;
	
	my $func = 'function(){}';
	if ($field->{editable}) {
		$func = 'function(rec,fld) {' .
			'Ext.ux.EditRecordField({' . 
				'Record: rec,' .
				'fieldName: fld["name"],' .
				'fieldLabel: fld["label"],' .
				'fieldType: "textfield"' . 
			'});' .
		'}';
	}
	return RapidApp::JSONFunc->new( raw => 1, func => $func );
}





#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;