package RapidApp::HTML::Snippet::TagProcessor;
use Moose;

use RapidApp::Include qw(sugar perlutil);

#use Clone;

has 'tag' => ( is => 'ro', isa => 'Str', required => 1 );
has 'selector' => ( is => 'ro', isa => 'Maybe[CodeRef]', default => undef );
has 'processor' => ( is => 'ro',	isa => 'CodeRef', required => 1 );
has 'single_token' => ( is => 'ro', isa => 'Bool', default => 0 );

has 'count' => ( is => 'rw', isa => 'Int', default => 0 );
has 'active' => ( is => 'rw', isa => 'Bool', default => 0 );

has 'Snippet' => ( 
	is => 'ro', 
	isa => 'RapidApp::HTML::Snippet', 
	required => 1,
	handles => {
		current_token	=> 'current_token'
	}
);

has 'instances' => (
	is => 'rw',
	traits => [ 'Array' ],
	isa => 'ArrayRef[' . __PACKAGE__ . ']',
	default => sub {[]},
	handles => {
		unshift_instance	=> 'unshift',
		shift_instance		=> 'shift'
	}
);

has 'last_processed_token' => ( is => 'rw', isa => 'Maybe[Object]', default => undef );

has 'tag_depth' => ( is => 'rw', isa => 'Int', default => 0 );
after 'tag_depth' => sub {
	my $self = shift;
	my $arg = shift;
	$self->current_instance->tag_depth($arg) if (defined $arg and $self->current_instance);
};

sub process {
	my $self = shift;
	
	# Skip if we've already processed this token:
	return undef if (
		defined $self->last_processed_token and 
		$self->current_token == $self->last_processed_token
	);
	
	$self->load_instance if ($self->matched_start_tag);
	
	return undef unless ($self->active);
	
	
	
	my $result = $self->current_instance->call_process;
	$self->last_processed_token($self->current_token);
	$self->unload_instance if ($self->matched_end_tag);
	
	return $result;
}


sub current_instance {
	my $self = shift;
	return $self->instances->[0];
}


sub matched_start_tag {
	my $self = shift;
	return 0 unless ( $self->current_token->is_start_tag($self->tag) );
	
	if (defined $self->selector and not $self->selector->($self->current_token)) {
		$self->tag_depth( $self->tag_depth + 1 ) if ($self->active);
		return 0;
	}
	
	return 1;
}

sub matched_end_tag {
	my $self = shift;
	return 1 if ( $self->single_token );
	
	if ($self->current_token->is_end_tag($self->tag)) {
		return 1 unless ($self->tag_depth);
		$self->tag_depth( $self->tag_depth - 1 );
	}
		
	return 0;
}

sub call_process {
	my $self = shift;
	$self->count( $self->count + 1 );
	return $self->processor->($self,$self->current_token);
}


sub load_instance {
	my $self = shift;
	$self->unshift_instance($self->clone);
	$self->current_instance->count(0);
	$self->current_instance->instances([]);
	$self->active(1);
	$self->Snippet->active_Processors->{$self} = $self;	
}

sub unload_instance {
	my $self = shift;
	$self->shift_instance;
	unless (defined $self->current_instance) {
		$self->active(0);
		delete $self->Snippet->active_Processors->{$self};
	}
}

sub clone {
	my ($self, %params) = @_;
	$self->meta->clone_object($self, %params);
}



1;
