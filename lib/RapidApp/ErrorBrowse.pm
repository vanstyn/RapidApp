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
		#hidden 		=> \1,
		render_fn	=> 'Ext.ux.showNull'
	);
	
	my @colOpts= (
		id => { width => 30, header => 'ID' },
	);
	$self->batch_apply_opts(
		columns => { @colOpts },
		column_order => [ grep(!ref $_, @colOpts) ],
		sort => {
			field		=> 'id',
			direction	=> 'DSC'
		}
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


no Moose;
__PACKAGE__->meta->make_immutable;
1;
