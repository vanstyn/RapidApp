package RapidApp::AppCombo2;
use Moose;
extends 'RapidApp::AppCmp';
with 'RapidApp::Role::DataStore2';

use strict;

use RapidApp::Include qw(sugar perlutil);

has 'name' 					=> ( is => 'ro', required => 1, isa => 'Str' );
has 'displayField' 		=> ( is => 'ro', required => 1, isa => 'Str' );
has 'valueField' 			=> ( is => 'ro', required => 1, isa => 'Str' );
has 'fieldLabel' 			=> ( is => 'ro', lazy => 1, default => sub { (shift)->name } );

sub BUILD {
	my $self = shift;
	
	$self->apply_extconfig(
		xtype				=> 'appcombo2',
		typeAhead		=> \0,
		mode				=> 'remote',
		triggerAction	=> 'all',
		selectOnFocus	=> \1,
		editable			=> \0,
		allowBlank 		=> \0,
		width 			=> 337,
		name 				=> $self->name,
		fieldLabel 		=> $self->fieldLabel,
		displayField 	=> $self->displayField,
		valueField 		=> $self->valueField,
	);
}

sub web1_render {
	my ($self, $renderCxt, $extCfg)= @_;
	
	# simulate a get request to the grid's store
	my $storeFetchParams= $extCfg->{store}{parm}{baseParams};
	my $origParams= $self->c->req->params;
	my $data;
	try {
		$self->c->req->params($storeFetchParams);
		$data= $self->Module('store')->read();
		$self->c->req->params($origParams);
	}
	catch {
		$self->c->req->params($origParams);
		die $_;
	};
	
	# now we need to find the row that corresponds to the value
	my $value= $extCfg->{value};
	my $valueField= $extCfg->{valueField};
	my $selectedRow;
	
	$self->c->log->debug((ref $self)." looking for $valueField=$value.' in ".Data::Dumper::Dumper($data->{rows}));
	
	if (ref $data->{rows} eq 'ARRAY' && scalar(@{$data->{rows}}) ) {
		for my $row (@{$data->{rows}}) {
			if ($value eq $row->{$valueField}) {
				$selectedRow= $row;
				last;
			}
		}
	}
	
	$renderCxt->write('<div class="xt-appcombo2">');
	if ($selectedRow) {
		$self->web1_render_list_item($renderCxt, $selectedRow, $extCfg->{tpl});
	}
	else {
		$renderCxt->write('<span class="val">&nbsp;</span>');
	}
	$renderCxt->write("</div>\n");
}

=pod

This is a cheesy hack attempt at processing an xtemplate.
If we come up with a better engine for that, replace this code with a call to it.
In the meantime, you can override this method to do custom rendering in your module.

=cut
sub web1_render_list_item {
	my ($self, $renderCxt, $row, $template)= @_;
	my $text= $template;
	$template =~ s|</?tpl[^>]+>||g;
	my @parts= split /[{}]/, $template;
	for (my $i=1; $i <= $#parts; $i+= 2) {
		if (substr($parts[$i], 0, 1) eq '[') {
			$self->c->log->warn("You need to write a custom 'web1_render_list_item' for ".(ref $self));
			$parts[$i]= '[unrenderable content]';
		}
		else {
			$parts[$i]= $renderCxt->escHtml($row->{$parts[$i]});
		}
	}
	my $html= join '', @parts;
	$self->c->log->debug("Before: $template\nAfter: $html");
	$renderCxt->write($html);
}

no Moose;
#__PACKAGE__->meta->make_immutable;
1;