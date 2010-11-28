package RapidApp::Error;

use strict;
use warnings;
use Exception::Class;
use base 'Exception::Class::Base';

use Data::Dumper;
use Devel::StackTrace::WithLexicals;

BEGIN {
	my @newFields= qw{cause diag full_message_fn full_diag_fn};
	
	my $code= 'sub Fields { return ( $_[0]->SUPER::Fields, "'.(join '","',@newFields).'" ); };';
	for my $f (@newFields) {
		$code.= 'sub '.$f.' { defined $_[1] and $_[0]->{'.$f.'}= $_[1]; return $_[0]->{'.$f.'}; };';
	}
	eval $code;
}

sub dieConverter {
	if (ref $_[0] eq '') {
		my $msg= join ' ', @_;
		$msg =~ s/ at [^ ]+.p[lm] line.*//;
		die RapidApp::Error->new(message => $msg);
	}
}

sub new {
	my $self= Exception::Class::Base::new(@_);
	
	# if catalyst is in debug mode, we capture a FULL stack trace
	my $c= RapidApp::ScopedGlobals->catalystInstance;
	#if (defined $c && $c->debug) {
	#	$self->{trace}= Devel::StackTrace::WithLexicals->new(ignore_class => [ __PACKAGE__ ]);
	#}
	return $self;
}

sub dump_ignore_fields {
	return qw{message diag cause full_message_fn trace};
}

sub dump {
	my $self= shift;
	
	# start with the readable messages
	my $result= $self->full_message."\n";
	
	if ((defined($self->diag) && length($self->diag)) || defined($self->full_diag_fn)) {
		$result.= 'Diag: '.$self->full_diag."\n" ;
	}
	
	# dump any misc properties
	my %ignore= map { $_ => 1 } $self->dump_ignore_fields;
	while ( my ($key, $val)= each %{$self} ) {
		next if $ignore{$key};
		$result.= "$key: ".(ref $val? Dumper($val) : "$val")."\n";
	}
	
	$result.= 'Stack: '.$self->trace."\n" if defined $self->trace;
	if (defined $self->cause) {
		$result.= 'Caused by: '.($self->cause->can('dump')? $self->cause->dump : ''.$self->cause);
	}
	return $result;
}

sub full_message {
	my $self= shift;
	defined $self->full_message_fn and return $self->full_message_fn->($self);
	return $self->SUPER::full_message;
}

sub full_diag {
	my $self= shift;
	defined $self->full_diag_fn and return $self->full_diag_fn->($self);
	return $self->diag;
}

sub as_string {
	return (shift)->message;
}

1;