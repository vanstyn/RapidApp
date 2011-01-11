package RapidApp::Web1RenderContext::ExtCfgToHtml::Form;
use Moose::Role;

sub render_xtype_form {
	my ($self, $renderCxt, $cfg)= @_;
	
	$renderCxt->incCSS('/static/rapidapp/css/web1_ExtJSForm.css');
	
	# make sure we have items to render
	defined $cfg->{items} && scalar(@{$cfg->{items}}) > 0
		or return $renderCxt->write('<table class="xt-form"> </table>');
	
	# build the completed list of items
	my %defaults= defined $cfg->{defaults}? %{$cfg->{defaults}} : ();
	my $itemList= [ map { {%defaults, %$_} } @{$cfg->{items}} ];
	return $self->render_layout_form($renderCxt, $itemList);
}

sub render_layout_form {
	my ($self, $renderCxt, $itemList)= @_;
	$renderCxt->write("<table class='xt-form'>\n");
	for my $item (@$itemList) {
		$renderCxt->write(defined $item->{fieldLabel}?
			'<tr><td class="label">'.$item->{fieldLabel}.'</td><td>'
			: '<tr><td colspan="2">');
		$self->renderAsHtml($renderCxt, $item);
		$renderCxt->write("</td></tr>\n");
	}
	return $renderCxt->write("</table>\n");
}

sub render_xtype_displayfield {
	my ($self, $renderCxt, $cfg)= @_;
	my $val= defined $cfg->{value}? $cfg->{value} : '&nbsp;';
	$renderCxt->write('<div class="xt-displayfield">'.$val.'</div>');
}

sub render_xtype_textfield {
	my ($self, $renderCxt, $cfg)= @_;
	my $val= defined $cfg->{value}? $cfg->{value} : '&nbsp;';
	$renderCxt->write('<div class="xt-textfield">'.$val.'</div>');
}

sub render_xtype_numberfield {
	render_xtype_textfield(@_);
}

no Moose;
1;