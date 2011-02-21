package RapidApp::Debug;

use Term::ANSIColor;
use Data::Dumper;
use RapidApp::ScopedGlobals;

sub write_debug_msg {
	my ($chanName, @args)= @_;
	return unless $ENV{$chanName};
	
	my $log= RapidApp::ScopedGlobals->get('log');
	if (!$log) {
		warn "RapidApp::Debug: no log available";
		return;
	}
	
	my $cfg= _get_channel_cfg($chanName);
	my $color= $cfg->{color} ||= Term::ANSIColor::YELLOW;
	
	my $locInfo= '';
	if ($cfg->{showSrcLoc}) {
		my ($ignore, $srcFile, $srcLine)= (caller);
		$srcFile =~ s|^.*lib/||;
		$locInfo = $srcFile . ' line '. $srcLine . "\n";
	}
	
	my @argText= map { $self->_debug_data_to_text($_) } @args;
	my $msg= join(' ', $locInfo, $color, @argText, Term::ANSIColor::CLEAR );
	
	$log->debug($msg);
}

sub _get_channel_cfg {
	my $chname= shift;
	
	my ($c, $app, $debug_cfg, $cfg);
	$debug_cfg=
		(($c= RapidApp::ScopedGlobals->get('catalystInstance')) && ($c->config->{Debug} ||= {}))
		|| (($app= RapidApp::ScopedGlobals->get('catalystClass')) && ($app->config->{Debug} ||= {}))
		|| {};
	$debug_cfg->{channels} ||= {};
	return $debug_cfg->{channels}{$category} ||= {};
}

sub _debug_data_to_text {
	my ($self, $data)= @_;
	ref $data or return $data;
	ref $data eq 'CODE' and return &$data;
	my $dump= Data::Dumper->new([$data], [''])->Indent(1)->Maxdepth(5)->Dump;
	$dump =~ s/^[^{]+//;
	length($dump) > 2000
		and $dump= substr($dump, 0, 2000)."\n...\n...";
	return $dump;
}

1;