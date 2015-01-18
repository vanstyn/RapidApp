package RapidApp::Tree::TreeNode;
#
# Very old code, was originally RapidApp::ExtJS::TreeNode
#
# -------------------------------------------------------------- #
#
#
# 2009-12-09:	Version 0.2 (HV)
#	Initial dev


use strict;




my $VERSION = '0.1';


sub new {
	my $class = shift;
	my $self = bless {}, $class;
	
	$self->Params(shift) or die "invalid parameters";
	
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
		
		$p->{expanded}		= 1 			unless (defined $p->{expanded});
		
		$self->{Params} = $p;
	}
	
	$self->{Params}->{leaf} 		= $self->leaf;
	$self->{Params}->{children} 	= $self->children if (defined $self->children);
	
	return $self->{Params};
}

sub leaf {
	my $self = shift;
	return 1 if ($self->children_count == 0);
	return 0;
}

sub children_count {
	my $self = shift;
	return 0 unless (defined $self->children and ref($self->children) eq 'ARRAY');
	return scalar(@{$self->children});
}

sub children {
	my $self = shift;
	$self->{children} = $self->{Params}->{children} if (
		defined $self->{Params}->{children} and
		not defined $self->{children}
	);
	$self->{children} = [] unless (defined $self->{children});
	push(@{$self->{children}}, @_) if (scalar(@_) > 0);
	return $self->{children};
}


1;