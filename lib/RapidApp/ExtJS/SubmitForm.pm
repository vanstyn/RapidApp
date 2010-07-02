package RapidApp::ExtJS::SubmitForm;
#
# -------------------------------------------------------------- #
#
#   -- Catalyst/Ext-JS - Ext.ux.SubmitFormPanel
#
#
# 2010-06-10:	Version 0.1 (HV)
#	Initial development


use strict;
use Moose;

extends 'RapidApp::ExtJS::ConfigObject';

use RapidApp::ExtJS::MsgBox;

our $VERSION = '0.1';

#### --------------------- ####

has 'url'						=> ( is => 'ro', required => 1										);

has 'xtype'						=> ( is => 'ro',	default => 'submitform'							);
has 'id'							=> ( is => 'ro',	default => 'submitform-id' 		 			);
has 'labelAlign'				=> ( is => 'ro',	default => 'left' 					 			);
has 'bodyStyle'				=> ( is => 'ro',	default => 'padding:5px 5px 0'	 			);
has 'frame'						=> ( is => 'ro',	default => 1					 		 			);
has 'autoScroll'				=> ( is => 'ro',	default => 1 		 								);
has 'items'						=> ( is => 'ro',	default => sub {[]} 								);

has 'submit_btn_text'		=> ( is => 'ro',	default => 'Save'	 								);
has 'submit_btn_iconCls'	=> ( is => 'ro',	default => 'icon-save'	 						);
has 'cancel_btn_text'		=> ( is => 'ro',	default => 'Cancel' 								);
has 'cancel_btn_iconCls'	=> ( is => 'ro',	default => undef	 								);

has 'monitorValid'			=> ( is => 'ro',	default => 0 		 								);

has 'exception_style' 	=> ( is => 'ro',	required => 0,		default => "color: red; font-weight: bolder;"			);

has 'buttons'				=> ( is => 'ro',	lazy_build => 1	 								);
has 'extra_buttons'		=> ( is => 'ro',	default => sub {[]}, isa => 'ArrayRef'		);
has 'onFail_eval'			=> ( is => 'ro',	lazy_build => 1	 								);
has 'onSuccess_eval'		=> ( is => 'ro',	lazy_build => 1	 								);
has 'after_save_code'	=> ( is => 'ro',	default => ''		 								);
has 'close_on_success'	=> ( is => 'ro',	default => 0 		 								);



sub _build_buttons {
	my $self = shift;
	
	my $save = {
		xtype				=> 'dbutton',
		text				=> $self->submit_btn_text,
		iconCls			=> $self->submit_btn_iconCls,
		handler_func	=> $self->btn_submit_func
	};
	
	my $cancel = {
		xtype				=> 'dbutton',
		text				=> $self->cancel_btn_text,
		iconCls			=> $self->cancel_btn_iconCls,
		handler_func	=> $self->form_close_from_btn_code('btn')
	};
	
	return [ @{$self->extra_buttons}, $save, $cancel ];
}


sub _build_onFail_eval {
	my $self = shift;
	
	my %MsgBox = (
		title		=> 'Error', 
		msg 		=> 'action.result.msg', 
		style => $self->exception_style
	);
	
	return RapidApp::ExtJS::MsgBox->new(%MsgBox)->code;
}


sub _build_onSuccess_eval {
	my $self = shift;
	
	my $code = $self->after_save_code;

	if ($self->close_on_success) {
		$code .= 
			q~var formcomp = Ext.getCmp('~ . $self->id . q~').ownerCt; ~ .
			q~try {~ .
				$self->form_cmp_close_code('formcomp') .
			q~} catch (err) {~ .
				q~var TabP = formcomp.findParentByType('tabpanel');~ .
				$self->form_cmp_close_code('TabP') .
			q~}~
	}

	return $code;
}


sub form_close_from_btn_code {
	my $self = shift;
	my $btn = shift or return;
	
	return 

		q~var par_cmp = ~ . $btn . q~.findParentByType('window'); ~ .
		q~if(!par_cmp) { par_cmp = ~ . $btn . q~.findParentByType('tabpanel'); } ~ .
		$self->form_cmp_close_code('par_cmp');

}


sub form_cmp_close_code {
	my $self = shift;
	my $cmp = shift;

	return 
		q~try {~ .
			$cmp . q~.close();~ .
		q~} catch(err) {~ .
			q~var activePanel = ~ . $cmp . q~.getActiveTab(); ~ .
			$cmp . q~.remove(activePanel); ~ .
		q~}~
	;

}


sub btn_submit_func {
	my $self = shift;
	
	my $submit_handler = q~btn.findParentByType('submitform').submitProcessor();~;
	
	$submit_handler = q~if(btn.findParentByType('submitform').getForm().isValid()) {~ . $submit_handler . '}' if (
		$self->monitorValid
	);
	
	return $submit_handler;
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;