package RapidApp::ErrorBrowse;

use Moose;
extends 'RapidApp::DbicAppGrid2';

use RapidApp::Include 'perlutil', 'sugar';
use RapidApp::ErrorView;
use RapidApp::DbicExtQuery;
use RapidApp::DbicErrorStore;

has 'errorReportStore' => ( is => 'rw', isa => 'Maybe[RapidApp::DbicErrorStore|Str]' );

sub resolveErrorReportStore {
	my $self= shift;
	
	my $store= $self->errorReportStore;
	defined $store
		and return (ref $store? $store : $self->c->model($store));
	
	return $self->app->rapidApp->resolveErrorReportStore;
}

sub ResultSource {
	my $self= shift;
	my $store= $self->resolveErrorReportStore;
	$store->isa('RapidApp::DbicErrorStore') or die "Can only browse error stores of type RapidApp::DbicErrorStore";
	return $store->resultSource;
}

override_defaults(
	record_pk => 'id',
	title     => 'Exceptions',
	auto_web1 => 1,
	#auto_viewport => 1,
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
		id      => { width =>  30, header => 'ID' },
		when    => { width => 120, header => 'Date', render_fn => 'Ext.ux.RapidApp.renderUtcDate' },
		summary => { width => 900, header => 'Summary' },
		report  => { hidden => \1 },
	);
	$self->batch_apply_opts(
		columns => { @colOpts },
		column_order => [ grep(!ref $_, @colOpts) ],
		sort => { field => 'id', direction => 'DESC' },
	);
}

sub getjs_simpleRequestor {
	my ($self, $url, $params)= @_;
	return mixedjs 'function() { Ext.Ajax.request( ',
		{ url => $url,
		  success => rawjs('function (response, opts) { Ext.Msg.alert("success"); }'),
		  #failure => rawjs('function (response, opts) { Ext.Msg.alert("failure"); }'),
		  params => $params,
		}, ' ); }';
}

sub options_menu_items {
	my $self= shift;
	return [
		{ text => 'Generate Internal Error', handler => $self->getjs_simpleRequestor($self->suburl('item/gen_error')) },
		{ text => 'Generate User Error',     handler => $self->getjs_simpleRequestor($self->suburl('item/gen_usererror')) },
		{ text => 'Generate User-facing exception', handler => $self->getjs_simpleRequestor($self->suburl('item/gen_userexception')) },
		{ text => 'Generate User-facing exception 2', handler => $self->getjs_simpleRequestor($self->suburl('item/gen_userexception_complex')) },
		{ text => 'Generate Perl Exception', handler => $self->getjs_simpleRequestor($self->suburl('item/gen_die')) },
		{ text => 'Generate DBIC Exception', handler => $self->getjs_simpleRequestor($self->suburl('item/gen_dbicerr')) },
		{ text => 'Generate CustomPrompt',   handler => $self->getjs_simpleRequestor($self->suburl('item/gen_custprompt')) },
	];
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
