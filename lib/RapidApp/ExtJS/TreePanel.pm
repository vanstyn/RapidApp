package RapidApp::ExtJS::TreePanel;
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
			defined $p->{root}
		);
		
		$p->{xtype} 		= 'treepanel'	unless (defined $p->{xtype});
		$p->{layout} 		= 'fit'			unless (defined $p->{fit});
		$p->{collapsible} = 0				unless (defined $p->{collapsible});
		$p->{autoScroll} 	= 1				unless (defined $p->{autoScroll});
		$p->{'split'}		= 1				unless (defined $p->{'split'});
		$p->{loader}		= { xtype => 'treeloader' }	unless (defined $p->{loader});
		$p->{rootVisible}	= 0				unless (defined $p->{rootVisible});
		

		$self->{Params} = $p;
	}
	
	
	return $self->{Params};
}



1;