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

sub web1_render_extcfg {
	my ($self, $renderCxt, $extCfg)= @_;
	
	$renderCxt->incCSS('/static/rapidapp/css/web1_ExtJSMisc.css');
	
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
	my @values= split ',', $extCfg->{value};
	my $valueField= $extCfg->{valueField};
	my @selectedRows;
	
	#$self->c->log->debug((ref $self)." looking for $valueField=[".join(',',@values)."] in ".Data::Dumper::Dumper($data->{rows}));
	
	if (ref $data->{rows} eq 'ARRAY' && scalar(@{$data->{rows}}) ) {
		for my $row (@{$data->{rows}}) {
			for my $val (@values) {
				$val eq $row->{$valueField}
					and push @selectedRows, $row;
			}
		}
	}
	
	$renderCxt->write('<div class="xt-appcombo2">');
	$self->web1_render_list_items($renderCxt, \@selectedRows, $extCfg->{tpl});
	$renderCxt->write("</div>\n");
}

=pod

This is a cheesy hack attempt at processing an xtemplate.
If we come up with a better engine for that, replace this code with a call to it.
In the meantime, you can override this method to do custom rendering in your module.

=cut
sub web1_render_list_items {
	my ($self, $renderCxt, $rows, $template)= @_;
=pod
	my $text= $template;
	$template =~ s|</?tpl[^>]+>||g;
	my @parts= split /[{}]/, $template;
	for (my $i=1; $i <= $#parts; $i+= 2) {
		if (substr($parts[$i], 0, 1) eq '[') {
			$self->c->log->warn("You need to write a custom 'web1_render_list_items' for ".(ref $self));
			$parts[$i]= '[unrenderable content]';
		}
		else {
			$parts[$i]= $renderCxt->escHtml($row->{$parts[$i]});
		}
	}
	my $html= join '', @parts;
	$self->c->log->debug("Before: $template\nAfter: $html");
	$renderCxt->write($html);
=cut
	if ($self->can('web1_render_getListItemContent')) {
		if (scalar(@$rows) == 0) {
			$renderCxt->write('<span class="value-placeholder">(unset)</span>');
		}
		elsif (scalar(@$rows) == 1) {
			$renderCxt->write($self->web1_render_getListItemContent($rows->[0]));
		}
		else {
			my @items= map { '<li>'.$self->web1_render_getListItemContent($_).'</li>' } @$rows;
			$renderCxt->write('<ul>'.(join '', @items).'</ul>');
		}
	}
	else {
		$self->c->log->warn("You need to write a custom 'web1_render_list_items' or 'web1_render_getListItemContent' for ".(ref $self));
		$renderCxt->write('[unrenderable content]');
	}
}

no Moose;
#__PACKAGE__->meta->make_immutable;
1;