package RapidApp::ExtCfgToHtml::Form;

use strict;
use warnings;
use RapidApp::ExtCfgToHtml;

{ # Register these functions with the RenderContext
	my @xtypes= qw(form textfield numberfield displayfield);
	for my $xt (@xtypes) {
		my $methodName= "render_xtype_$xt";
		RapidApp::ExtCfgToHtml->registerXtypeRenderFunction($xt => \&$methodName);
	}
	
	push @RapidApp::ExtCfgToHtml::ISA, __PACKAGE__;
}

sub render_xtype_form {
	my ($self, $context, $cfg)= @_;
	
	$context->incCSS('/static/rapidapp/css/web1_ExtJSForm.css');
	
	# make sure we have items to render
	defined $cfg->{items} && scalar(@{$cfg->{items}}) > 0
		or return $context->write('<table class="xt-form"> </table>');
	
	# build the completed list of items
	my %defaults= defined $cfg->{defaults}? %{$cfg->{defaults}} : ();
	my $itemList= [ map { {%defaults, %$_} } @{$cfg->{items}} ];
	return $self->render_layout_form($context, $itemList);
}

sub render_layout_form {
	my ($self, $context, $itemList)= @_;
	$context->write("<table class='xt-form'>\n");
	for my $item (@$itemList) {
		$context->write(defined $item->{fieldLabel}?
			'<tr><td class="label">'.$item->{fieldLabel}.'</td><td>'
			: '<tr><td colspan="2">');
		$self->render($context, $item);
		$context->write("</td></tr>\n");
	}
	return $context->write("</table>\n");
}

sub render_xtype_displayfield {
	my ($self, $context, $cfg)= @_;
	my $val= defined $cfg->{value}? $cfg->{value} : '&nbsp;';
	$context->write('<div class="xt-displayfield">'.$val.'</div>');
}

sub render_xtype_textfield {
	my ($self, $context, $cfg)= @_;
	my $val= defined $cfg->{value}? $cfg->{value} : '&nbsp;';
	$context->write('<div class="xt-textfield">'.$val.'</div>');
}

sub render_xtype_numberfield {
	render_xtype_textfield(@_);
}

1;