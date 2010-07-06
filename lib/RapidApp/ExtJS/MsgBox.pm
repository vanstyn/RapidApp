package RapidApp::ExtJS::MsgBox;
#
# -------------------------------------------------------------- #
#
#   -- Ext-JS Config Object
#
#
# 2010-04-16:	Version 0.1 (HV)
#	Initial development


use strict;
use Moose;


our $VERSION = '0.1';

#### --------------------- ####


has 'title' 				=> ( is => 'ro',	default => 'MsgBox'							);
has 'msg' 					=> ( is => 'ro',	default => ' '									);
has 'style'					=> ( is => 'ro',	default => ''									);
has 'buttons'				=> ( is => 'ro',	default => 'Ext.Msg.OK'						);
has 'icon'					=> ( is => 'ro',	default => 'Ext.MessageBox.WARNING'		);



sub code {
	my $self = shift;
	
	return q~Ext.Msg.show({~ .
				q~title: '~ . $self->title . q~',~ .
				q~msg: '<br><div style="~ . $self->style . q~">' + ~ . $self->msg . q~ + '</div>',~ .
				q~buttons: ~ . $self->buttons . q~,~ .
				q~icon: ~ . $self->icon . 
			q~});~;
}



no Moose;
__PACKAGE__->meta->make_immutable;
1;