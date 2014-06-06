package RapidApp::DBIC::DeclarationSugar;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT= qw(
	col smallint integer bigint char varchar binary varbinary blob text date datetime
	unsigned not_null auto_inc fk default
	relation db_cascade no_db_cascade dbic_cascade no_dbic_cascade deploy no_deploy
);

sub col {
	my ($name, @opts)= @_;
	my ($pkg)= caller;
	$pkg->add_column($name, { @opts });
}

sub smallint  { data_type => 'smallint',  size => 6 }
sub integer   { data_type => 'integer',   size => (defined $_[0]? $_[0] : 11) }
sub bigint    { data_type => 'bigint',    size => 22 }
sub char      { data_type => 'char',      size => (defined $_[0]? $_[0] : 1) }
sub varchar   { data_type => 'varchar',   size => (defined $_[0]? $_[0] : 255) }
sub binary    { data_type => 'binary',    size => (defined $_[0]? $_[0] : 255) }
sub varbinary { data_type => 'varbinary', size => (defined $_[0]? $_[0] : 255) }
sub date      { data_type => 'date' }
sub datetime  { data_type => 'datetime' }
sub unsigned  { extra => { unsigned => 1 } }
sub not_null  { is_nullable => 0 }
sub auto_inc  { is_auto_increment => 1 }
sub fk        { is_foreign_key => 1 }
#sub pk        { is_primary_key => 1 }
sub default   { default_value => (scalar(@_) > 1? [ @_ ] : $_[0]) }

my %blobsizenames= ( med => 0xFFFFFF, medium => 0xFFFFFF, long => 0xFFFFFFFF, tiny => 0xFF );
sub blob      {
	my $size= shift || 0xFFFFFF;
	unless ($size =~ /[0-9]+/) {
		$blobsizenames{$size} or die "Unrecognized blob size modifier: $size";
		$size= $blobsizenames{$size};
	}
	my $tname= ($size > 0xFFFFFF? 'longblob' : ($size > 0xFFFF? 'mediumblob' : ($size > 0xFF? 'blob' : 'tinyblob')));
	
	return data_type => $tname, size => $size;
}
sub text      {
	my @result= blob(@_);
	$result[1] =~ s/blob/text/;
	return @result;
}

sub relation {
	my ($name, $relType, $fieldMap, @opts)= @_;
	my ($pkg)= caller;
	my @pkgParts= split /::/, $pkg;
	my $sourceName= pop @pkgParts;
	my $peerSourceName;
	_translateFieldMap($fieldMap, \$peerSourceName);
	my $peerClass= join('::', @pkgParts, $peerSourceName);
	
	# here, we call the normal package method.
	# i.e.  __PACKAGE__->belongs_to($name, $relatedPkg, { self.foo => foreign.bar }, { %opts } );
	use RapidApp::Debug 'DEBUG';
	DEBUG('declaration_sugar', $pkg, '->', $relType, '(', $name, $peerClass, $fieldMap, '{', @opts, '})');
	$pkg->$relType($name, $peerClass, $fieldMap, { @opts });
}

sub no_db_cascade { db_cascade('RESTRICT') }
sub db_cascade {
	my $mode= scalar(@_)? $_[0] : 'CASCADE';
	return
		on_update => $mode,
		on_delete => $mode,
}

sub no_dbic_cascade { dbic_cascade(0) }
sub dbic_cascade {
	my $enable= defined $_[0]? $_[0] : 1;
	return
		cascade_copy => $enable,
		cascade_delete => $enable;
}

sub no_deploy { deploy(0) }
sub deploy {
	my $enable= defined $_[0]? $_[0] : 1;
	return is_foreign_key_constraint => $enable;
}

sub _translateFieldMap {
	my ($map, $foreignName)= @_;
	my @items;
	for my $key (keys %$map) {
		index($key, '.') == -1 or die "keys of relation should be column name only, of the current table";
		my $local= 'self.'.$key;
		
		my @parts= split /\./, $map->{$key};
		my $foreign;
		if (scalar(@parts)) {
			$$foreignName ||= $parts[0];
			$$foreignName eq $parts[0] or die "Relation may only reference one foreign table. (we see $foreignName and ".$parts[0].")";
			$parts[0]= 'foreign';
			$foreign= join('.', @parts);
		} else {
			$foreign= 'foreign.'.$_;
		}
		push @items, $foreign => $local;
	}
	$$foreignName or die "Relation mapping must contain the name of the foreign ResultSource in at least one of the values";
	%$map= ( @items );
}

1;