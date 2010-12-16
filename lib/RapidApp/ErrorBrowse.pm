package RapidApp::ErrorBrowse;

use Moose;
extends 'RapidApp::DbicAppGrid2';

use RapidApp::Include 'perlutil', 'sugar';
use RapidApp::ErrorView;
use RapidApp::DbicExtQuery;

has 'exceptionStore' => ( is => 'rw', isa => 'RapidApp::DbicExceptionStore' );

sub ResultSource {
	return (shift)->exceptionStore->resultSource;
}

override_defaults(
	record_pk => 'id',
	title     => 'Exceptions',
	auto_web1 => 1,
	auto_viewport => 1,
	open_record_class => sub {{
		class => 'RapidApp::ErrorView',
		params => { edit_mode => 1, useParentExceptionStore => 1 }
	}},
);

sub BUILD {
	my $self= shift;
	
	$self->apply_to_all_columns(
		render_fn	=> 'Ext.ux.showNull'
	);
	
	my @colOpts= (
		id    => { width =>  30, header => 'ID' },
		when  => { width => 120, header => 'Date' },
		who   => { width =>  70, header => 'User' },
		what  => { width => 250, header => 'Message' },
		where => { width => 250, header => 'Src Loc.' },
		why   => { hidden => \1 },
	);
	$self->batch_apply_opts(
		columns => { @colOpts },
		column_order => [ grep(!ref $_, @colOpts) ],
		sort => { field => 'id', direction => 'DESC' },
	);
}

sub content {
	my $self= shift;
	my $extcfg= $self->get_complete_extconfig;
	$self->log->debug("xtype ".$extcfg->{xtype});
	return $extcfg;
}

sub viewport {
	my $self= shift;
	my $extcfg= $self->get_complete_extconfig;
	$self->log->debug("xtype ".$extcfg->{xtype});
	return $self->SUPER::viewport;
}

sub getjs_simpleRequestor {
	my ($self, $url)= @_;
	return 'function() { Ext.Ajax.request( { url: "'.$url.'" } ); }';
}

sub options_menu_items {
	my $self= shift;
	return [
		{ text => 'Generate Internal Error', handler => rawjs $self->getjs_simpleRequestor($self->suburl('item/gen_error')) },
		{ text => 'Generate User Error', handler => rawjs $self->getjs_simpleRequestor($self->suburl('item/gen_usererror')) },
		{ text => 'Generate Perl Exception', handler => rawjs $self->getjs_simpleRequestor($self->suburl('item/gen_die')) },
	];
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
