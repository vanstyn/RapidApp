package RapidApp::ExtJS::Button;
#
# -------------------------------------------------------------- #
#
#   -- Ext-JS Grid code object
#
#
# 2009-12-09:	Version 0.2 (HV)
#	Initial dev


use strict;




my $VERSION = '0.1';


sub new {
	my $class = shift;
	my $self = bless {}, $class;
	
	$self->Params(shift) or return undef;
	
	return $self;
}


sub Params {
	my $self = shift;
	unless (defined $self->{Params}) {
		my $p = shift;
		return undef unless (
			defined $p 						and
			ref($p) eq 'HASH' 				and
			defined $p->{text}
		);
		
		$p->{xtype} 		= 'dbutton'		unless (defined $p->{xtype});
		
		$self->{Params} = $p;
	}
	

	
	return $self->{Params};
}


1;