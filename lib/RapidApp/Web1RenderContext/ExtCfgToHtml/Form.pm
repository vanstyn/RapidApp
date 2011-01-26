package RapidApp::Web1RenderContext::ExtCfgToHtml::Form;
use Moose::Role;

sub render_xtype_form {
	my ($self, $renderCxt, $cfg)= @_;
	
	$renderCxt->incCSS('/static/rapidapp/css/web1_ExtJSForm.css');
	
	$cfg->{layout} ||= 'form';
	$self->render_xtype_panel($renderCxt, $cfg);
	
	# # make sure we have items to render
	# defined $cfg->{items} && scalar(@{$cfg->{items}}) > 0
		# or return $renderCxt->write('<table class="xt-form"> </table>');
	
	# # build the completed list of items
	# my %defaults= defined $cfg->{defaults}? %{$cfg->{defaults}} : ();
	# my $itemList= [ map { {%defaults, %$_} } @{$cfg->{items}} ];
	# return $self->render_layout_form($renderCxt, { items => $itemList });
}

sub render_layout_form {
	my ($self, $renderCxt, $items, $parent)= @_;
	my $wid= defined $parent->{labelWidth}? ' style="width:'.$parent->{labelWidth}.'"' : '';
	$renderCxt->write("<table class='ly-form'>\n");
	for my $item (@$items) {
		$renderCxt->write(defined $item->{fieldLabel}?
			'<tr><td class="label"'.$wid.'>'.$item->{fieldLabel}.'</td><td>'
			: '<tr><td colspan="2">');
		$self->renderAsHtml($renderCxt, $item);
		$renderCxt->write("</td></tr>\n");
	}
	return $renderCxt->write("</table>\n");
}

sub render_xtype_displayfield {
	my ($self, $renderCxt, $cfg)= @_;
	# XXX who escapes the content of a displayField?  the server or the browser?
	my $val= defined $cfg->{value}? $cfg->{value} : '';
	my $wid= defined $cfg->{width}? ' style="width:'.$cfg->{width}.'"' : '';
	$renderCxt->write('<div class="xt-displayfield"'.$wid.'>'.$val.'&nbsp;</div>');
}

sub render_xtype_textfield {
	my ($self, $renderCxt, $cfg)= @_;
	my $val= defined $cfg->{value}? $renderCxt->escHtml($cfg->{value}) : '';
	my $wid= defined $cfg->{width}? ' style="width:'.$cfg->{width}.'"' : '';
	$renderCxt->write('<div class="xt-textfield"'.$wid.'>'.$val.'&nbsp;</div>');
}

sub render_xtype_numberfield {
	render_xtype_textfield(@_);
}

sub render_xtype_textarea {
	my ($self, $renderCxt, $cfg)= @_;
	my $val= defined $cfg->{value}? $renderCxt->escHtml($cfg->{value}) : '';
	my $wid= defined $cfg->{width}? ' style="width:'.$cfg->{width}.'"' : '';
	$val =~ s|\n|<br />|g;
	$renderCxt->write('<div class="xt-textfield"'.$wid.'>'.$val.'&nbsp;</div>');
}

sub render_xtype_xdatetime {
	# XXX TODO: implement this with the actual formatting strings used by ExtJS
	render_xtype_textfield(@_);
#	my ($self, $renderCxt, $cfg)= @_;
#	my $val= defined $cfg->{value}? $renderCxt->escHtml($cfg->{value}) : '';
#	$val =~ s|\n|<br />|g;
#	my $wid= defined $cfg->{width}? 'style="width:'.$cfg->{width}.'"' : '';
#	$renderCxt->write('<div class="xt-textfield"'.$wid.'>'.$val.'&nbsp;</div>');
}

sub render_xtype_checkbox {
	my ($self, $renderCxt, $cfg)= @_;
	$renderCxt->write('<span class="checkvalue">'.($cfg->{value}? "[Yes]":"[No]").'</span>');
}

no Moose;
1;