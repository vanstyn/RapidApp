package RapidApp::ExtCfgToHtml::Superbox;
use Moose::Role;

sub render_xtype_superboxselect {
	my ($self, $context, $cfg)= @_;
	$context->write("<h2>SUPERBOX</h2>");
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;