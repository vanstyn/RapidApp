package RapidApp::ColorLog;

use Moose;
extends 'Catalyst::Log';

use Term::ANSIColor qw(:constants);

has 'colorForLevel' => ( is => 'rw', lazy_build => 1 );
sub _build_colorForLevel {
	return {
		debug => CYAN.BOLD,
		info  => WHITE.BOLD,
		'warn' => YELLOW.BOLD,
		error => RED.BOLD,
		fatal => RED.BOLD,
	};
}

sub _log {
	my ($self, $level, @lines)= @_;
	my $message= join("\n", @lines);
	$message .= "\n" unless $message =~ /\n$/;
	my $color= $self->colorForLevel->{$level} || RED.BOLD;
	$message= sprintf("%s[%-5s]".CLEAR." %s", $color, $level, $message);
	$self->_body(($self->_body||'') . $message);
}

no Moose;
1;