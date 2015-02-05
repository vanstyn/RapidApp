package RapidApp::Module::StorCmp::Role::DbicLnk;

use strict;
use warnings;

use Moose::Role;
requires 'record_pk';


# Copied from (RapidApp::)Role::DbicLink2


use RapidApp::Include qw(sugar perlutil);
use RapidApp::TableSpec::DbicTableSpec;
use Clone qw(clone);
use Text::Glob qw( match_glob );
use Text::TabularDisplay;
use Time::HiRes qw(gettimeofday tv_interval);
use RapidApp::Data::Dmap qw(dmap);
use URI::Escape;
use Scalar::Util qw(looks_like_number);
use Digest::SHA1;

if($ENV{DBIC_TRACE}) {
  debug_around 'DBIx::Class::Storage::DBI::_execute', newline => 1, stack=>20;
}

our $append_exception_title = '';

# This allows supplying custom BUILD code via a constructor:
has 'onBUILD', is => 'ro', isa => 'Maybe[CodeRef]', default => undef;

has 'get_record_display' => ( is => 'ro', isa => 'CodeRef', lazy => 1, default => sub { 
  my $self = shift;
  return $self->TableSpec->get_Cnf('row_display');
});

# Useful for pages that display only the content of a single database record at a time.
# When set to true, rows are limited to "1" in the ResultSet in read_records and the
# pager is not used to perform the second query to get the total count
has 'single_record_fetch', is => 'ro', isa => 'Bool', default => 0;


# Colspec attrs can be specified as simple arrayrefs
has 'include_colspec' => ( is => 'ro', isa => 'ArrayRef[Str]', default => sub {[]} );
has 'relation_sep' => ( is => 'ro', isa => 'Str', default => '__' );

has 'updatable_colspec' => ( is => 'ro', isa => 'Maybe[ArrayRef[Str]]', default => undef );
has 'creatable_colspec' => ( is => 'ro', isa => 'Maybe[ArrayRef[Str]]', default => undef );

# Specify a list of relspecs to enable record destroy anmd specify which related rows
# should also be destroyed. For the base rel only, '*', specify other rels by name
# NOTE: This is simular in principle, but NOT the same as the colspecs. There is currently
# no real logic in this, no wildcard support, etc. It is just a list of relationship names
# that will be followed and be deleted along with the base. BE CAREFUL! This will delete whole
# sets of related rows. Most of the time you'll only want to put '*' in here
has 'destroyable_relspec' => ( is => 'ro', isa => 'Maybe[ArrayRef[Str]]', default => undef );

# New: List of relationship names to auto-create if they don't exist during an UPDATE
# TODO: make this a 'relspec' format like 'destroyable_relspec' above
has 'update_create_rels', is => 'ro', isa => 'ArrayRef[Str]', default => sub {[]};

# These columns will always be fetched regardless of whether or not they were requested
# by the client:
has 'always_fetch_colspec' => ( is => 'ro', isa => 'Maybe[ArrayRef[Str]]', default => undef );

# quicksearch_mode: either 'like' or 'exact' - see chain_Rs_req_quicksearch()
# currently any value other than 'exact' is treated like 'like', the default and
# original behavior.
# TODO: add 'phrases' mode to act like google searches with +/- and quotes around phrases
has 'quicksearch_mode', is => 'ro', isa => 'Str', default => 'like';

# Define if the user/client is allowed to specify the quicksearch_mode:
has 'allow_set_quicksearch_mode', is => 'ro', isa => 'Bool', default => 1;


# If natural_column_order is true (default) columns will be ordered according to the real
# database/schema order, otherwise, order is based on the include_colspec
has 'natural_column_order', is => 'ro', isa => 'Bool', default => 1;

has 'allow_restful_queries', is => 'ro', isa => 'Bool', default => 0;

# Generate a param string unique to this module by URL/path. This only needs to be unique
# among modules whose ->content may be rendered within the same request, which is only
# being done for good measure
has '_rst_qry_param', is => 'ro', isa => 'Str', lazy => 1, default => sub {
  my $self = shift;
  join('_',
    'rst_qry',
    substr(Digest::SHA1->new->add($self->base_url)->hexdigest, 0, 5)
  );
};
sub _appl_base_params {
  my ($self, $params) = @_;
  my $c = $self->c;
  
  %{$c->req->params} = ( %{$c->req->params}, %$params );
  
  my $baseParams = $self->DataStore->get_extconfig_param('baseParams') || {};
  %$baseParams = ( %$baseParams, %$params );
  $self->DataStore->apply_extconfig( baseParams => $baseParams );
}
sub _appl_rst_qry {
  my ($self, $val) = @_;
  $self->_appl_base_params({ $self->_rst_qry_param => $val });
}
sub _retr_rst_qry {
  my $self = shift;
  my $c = RapidApp->active_request_context or return undef;
  my $rst_qry = $c->req->params->{ $self->_rst_qry_param } or return undef;
  
  # Re-apply the rst_qry now to make sure there is not a caching issue
  # in the DataStore baseParams in case the normal rest logic doesn't
  # do this, which is the case when launched from a foreign component
  # by setting rest_args in the stash
  $self->_appl_rst_qry( $rst_qry );
  
  $rst_qry
}


has 'ResultSource' => (
  is => 'ro',
  isa => 'DBIx::Class::ResultSource',
  required => 1
);

has 'get_ResultSet' => ( is => 'ro', isa => 'CodeRef', lazy => 1, default => sub {
  my $self = shift;
  return sub { $self->ResultSource->resultset };
});

sub baseResultSet {
  my $self = shift;
  return $self->get_ResultSet->(@_);
}

sub _ResultSet {
  my $self = shift;
  
  my $p = $self->c->req->params;
  if($p->{rs_path} && $p->{rs_method}) {
    my $Module = $self->get_Module($p->{rs_path}) or die "Failed to get module at $p->{rs_path}";
    return $Module->_resolve_rel_obj_method($p->{rs_method});
  }
  
  my $Rs = $self->baseResultSet(@_);
  
  # the order of when this is called is vitally important:
  $self->prepare_rest_request;
  
  if(my $rst_qry = $self->_retr_rst_qry) {
    my ($key,$val) = split(/\//,$rst_qry,2);
    $Rs = $self->chain_Rs_REST($Rs,$key,$val);
  }

  $Rs = $self->ResultSet($Rs) if ($self->can('ResultSet'));
  return $Rs;
}

sub chain_Rs_REST {
  my ($self,$Rs,$key,$val) = @_;
  if ($key =~ /\./) {
    # if there is a '.' in the key name, assume it means 'rel.col', and
    # try to add the join for 'rel':
    my ($rel) = split(/\./,$key,2);
    $Rs = $self->_chain_search_rs($Rs,undef,{ join => $rel }) 
      if ($self->ResultSource->has_relationship($rel));
  }
  else {
    $key = 'me.' . $key;
  }
  return $self->_chain_search_rs($Rs,{ $key => $val });
}

has 'get_CreateData' => ( is => 'ro', isa => 'CodeRef', lazy => 1, default => sub {
  my $self = shift;
  return sub { {} };
});

sub baseCreateData {
  my $self = shift;
  return $self->get_CreateData->(@_);
}

sub _CreateData {
  my $self = shift;
  my $data = $self->baseCreateData(@_);
  $data = $self->CreateData($data) if ($self->can('CreateData'));
  return $data;
}

#sub _ResultSet {
#  my $self = shift;
#  my $Rs = $self->ResultSource->resultset;
#  $Rs = $self->ResultSet($Rs) if ($self->can('ResultSet'));
#  return $Rs;
#}

has 'ResultClass' => ( is => 'ro', lazy_build => 1 );
sub _build_ResultClass {
  my $self = shift;
  my $source_name = $self->ResultSource->source_name;
  return $self->ResultSource->schema->class($source_name);
}


has 'TableSpec' => ( is => 'ro', isa => 'RapidApp::TableSpec', lazy_build => 1 );
sub _build_TableSpec {
  my $self = shift;
  
  my $table = $self->ResultClass->table;
  $table = (split(/\./,$table,2))[1] || $table; #<-- get 'table' for both 'db.table' and 'table' format
  my %opt = (
    name => $table,
    relation_sep => $self->relation_sep,
    ResultSource => $self->ResultSource,
    include_colspec => $self->include_colspec
  );
  
  $opt{updatable_colspec} = $self->updatable_colspec if (defined $self->updatable_colspec);
  $opt{creatable_colspec} = $self->creatable_colspec if (defined $self->creatable_colspec);
  $opt{always_fetch_colspec} = $self->always_fetch_colspec if (defined $self->always_fetch_colspec);
  
  my $TableSpec = RapidApp::TableSpec::DbicTableSpec->new(%opt);
  
  $TableSpec->apply_natural_column_order if ($self->natural_column_order);
  
  return $TableSpec;
  #return RapidApp::TableSpec->with_traits('RapidApp::TableSpec::Role::DBIC')->new(%opt);
}


has 'record_pk' => ( is => 'ro', isa => 'Str', default => '___record_pk' );
has 'primary_columns_sep' => ( is => 'ro', isa => 'Str', default => '~$~' );
has 'primary_columns' => ( is => 'ro', isa => 'ArrayRef[Str]', lazy => 1, default => sub {
  my $self = shift;
  
  # If the db has no primary columns, then we have to use ALL the columns:
  unless ($self->ResultSource->primary_columns > 0) {
    my $class = $self->ResultSource->schema->class($self->ResultSource->source_name);
    $class->set_primary_key( $self->ResultSource->columns );
    $self->ResultSource->set_primary_key( $self->ResultSource->columns );
  }
  
  my @cols = $self->ResultSource->primary_columns;
  
  $self->apply_extconfig( primary_columns => [ $self->record_pk, @cols ] );

  return \@cols;
});


sub generate_record_pk_value {
  my $self = shift;
  my $data = shift;
  die "generate_record_pk_value(): expected hashref arg" unless (ref($data) eq 'HASH');
  return join(
    $self->primary_columns_sep, 
    #map { defined $data->{$_} ? "'" . $data->{$_} . "'" : 'undef' } @{$self->primary_columns}
    map { defined $data->{$_} ? $data->{$_} : 'undef' } @{$self->primary_columns}
  );
}

# reverse generate_record_pk_value:
sub record_pk_cond {
  my $self = shift;
  my $value = shift;
  
  my $sep = quotemeta $self->primary_columns_sep;
  my @parts = split(/${sep}/,$value);
  
  my %cond = ();
  foreach my $col (@{$self->primary_columns}) {
    my $val = shift @parts;
    if ($val eq 'undef') {
      $val = undef;
    }
    else {
      $val =~ s/^\'//;
      $val =~ s/\'$//;
    }
    # To force an *exact* match when col is a number, have to use LIKE because of the problem described here:
    #http://stackoverflow.com/questions/8570884/mysql-where-exact-match
    # Otherwise '1833sdfsdf' will match just like '1833'. But LIKE is slow!!! This is lame!
    #$cond{'me.' . $col} = { 'LIKE' => $val };
    $cond{'me.' . $col} = $val;
  }
  
  return \%cond;
}



# --- Handle RESTful URLs - convert 'id/1234' into '?___record_pk=1234'
#has 'restful_record_pk_alias', is => 'ro', isa => 'Str', default => '_id';
sub prepare_rest_request {
  my $self = shift;
  return unless ($self->allow_restful_queries);
  
  # New: allow override pf rest args from stash:
  my $stash_args = $self->c->stash->{rest_args};
  my @args = $stash_args ? @$stash_args : $self->local_args;
  
  $_ = uri_unescape($_) for (@args);
  
  my @rargs = reverse @args;
  
  # ignore paths that match store CRUD actions (store/create, store/read, store/update or store/destroy)
  # (TODO: what happens on the off chance that there is a key named 'store' and a value named 'read'?)
  my @crud = qw(create read update destroy);
  my %crudI = map {$_=>1} @crud;
  return if (
    $rargs[0] && $rargs[1] && 
    $rargs[1] eq 'store' && 
    $crudI{$rargs[0]}
  );
  
  # -- peel off the 'rel' (relationship) args if present:
  my $rel;
  if(scalar @args > 2) {
    if(lc($rargs[1]) eq 'rel' || lc($rargs[1]) eq 'rs') {
      $rel = pop @args;
      pop @args;
    }
  }
  # --
  
  # --- Handle and assume extra args are values containing '/'
  if(scalar @args > 1) {
    my @newargs = (shift @args);
    if (scalar @args > 0 && $self->ResultSource->has_column($newargs[0])) {
      push @newargs, join('/',@args);
    }
    else {
      @newargs = (join('/',@newargs,@args));
    }
    @args = @newargs;
  }
  # ---
  
  return unless defined $args[0];
  my $key = lc("$args[0]");
  my $val = $args[1];
  
  # Ignore paths that are submodules or actions:
  return if (exists $self->modules_obj->{$key} || $self->has_action($key));
  
  # if there was only 1 argument, treat it as the value and set the default key/pk:
  unless (defined $val) {
    $val = $args[0];
    my $rest_key_column = try{$self->ResultClass->getRestKey};
    $key = $rest_key_column || $self->record_pk;
  }
  
  # This should never happen any more (see "Handle and assume..." above):
  die usererr "Too many args in RESTful URL (" . join('/',@args) . ") - should be 2 (i.e. 'id/1234')"
    if(scalar @args > 2);
    
  return $self->redirect_handle_rest_rel_request($key,$val,$rel) if ($rel);
  
  # Apply default tabTitle: (see also 'getTabTitle' in DbicRowPage)
  $self->apply_extconfig( tabTitle => ($key eq $self->record_pk ? 'Id' : $key ) . '/' . $val );
  
  # ---
  # Update both the params of the active request, in place, as well as updating the baseParams
  # of the store for the subsequent read request:
  # TODO: '___record_pk' and 'rest_query' params are handled in different places in the subsequent
  # read request. '___record_pk' pre-dates the REST functionality and is only handled in DbicAppPropertyPage
  # (see the req_Row and and supplied_id methods in that class) while 'rest_query' is handled by
  # all modules with the DbicLink2 role. Need to consolidate these in DbicLink2 so this all happens in 
  # the same place
  if($key eq $self->record_pk) {
    $self->_appl_base_params({$key => $val});
  }
  else {
    $self->_appl_rst_qry( join('/',$key,$val) );
  }
  # ---
  
}


sub restGetRow {
  my ($self,$key,$val) = @_;
  
  my $Rs = $self->chain_Rs_REST($self->baseResultSet,$key,$val);
  
  # TODO: currently duplicated in DbicAppPropertyPage... it should defer to here
  my $count = $Rs->count;

  die usererr "Record not found by '$key/$val'", title => 'Record not found'
    unless ($count);
    
  die usererr $count . " records match '$key/$val'", title => 'Multiple records match'
    if($count > 1);

  return $Rs->first;
}

# This is designed to be called from *another* module to resolve a ResultSet
# object via arbitrary 'rs_method' path spec
sub _resolve_rel_obj_method {
  my ($self, $rs_method) = @_;
  my ($key,$val,$rel) = split('/',$rs_method,3);
  my $Row = $self->restGetRow($key,$val);
  die usererr "No such relationship $rel at ''$rs_method''" unless ($Row->has_relationship($rel));
  return $Row->$rel;
}

sub redirect_handle_rest_rel_request {
  my ($self,$key,$val,$rel) = @_;
  my $c = $self->c;
  
  my $mth_path = join('/',$key,$val,$rel);
  my $RelObj = $self->_resolve_rel_obj_method($mth_path);
  my $Src = $RelObj->result_source;
  my $class = $Src->schema->class($Src->source_name);
  
  $c->stash->{apply_extconfig} = {
    tabTitle => "[$key/$val] $rel"
  };
  
  if($RelObj->isa('DBIx::Class::ResultSet')) {
    my $url = try{$class->TableSpec_get_conf('open_url_multi')}
      or die usererr "No path (open_url_multi) defined to render Result Class: $class";

    %{$c->req->params} = (
      base_params => $self->json->encode({ 
        rs_path   => $self->module_path,
        rs_method => join('/',$key,$val,$rel)
      })
    );
  
    $c->root_module_controller->approot($c,$url);
    return $c->detach;
  }
  else {
    
    # New: here we are actually dispatching to the page for the single rel, but still
    # within the rest URL of the rel path. Ideally, for this case we would *redirect*
    # to the actual REST URL for thsi object, whatever it may be. In order to do this,
    # support for redirects needs to be added to the autopanel/hashnav stuff on the
    # client side. In the meantime, rendering the real/actual row page, albeit at an
    # alias (but still totally valid) url path is the best choice
    
    my $url = try{$RelObj->getRestPath};
    if($url) {
      # Simulate the rest_args for proper handling of the remote DbicLink
      # request to operate under the current, alias URL:
      $self->c->stash->{rest_args} = [$RelObj->getRestKey,$RelObj->getRestKeyVal];
      $c->root_module_controller->approot($c,$url);
      return $c->detach;
    }
    else {
      # This is just a fallback - TODO: use a better error msg...
      die usererr rawhtml join('',
        "Relationship at '$mth_path' is not a ResultSet, it is a Row",
        try{join(''," (",
          '<i><b style="color:darkblue;font-size:0.9em;">',
          $RelObj->displayWithLink,'</b></i>',
        ')')},
      ), title => 'Not a multi relationship'; 
    }
  }
}


# ---

sub BUILD {}
around 'BUILD' => sub { &DbicLink_around_BUILD(@_) };
sub DbicLink_around_BUILD {
  my $orig = shift;
  my $self = shift;
  
  die "FATAL: DbicLink and DbicLink2 cannot both be loaded" if ($self->does('RapidApp::Role::DbicLink'));
  
  $self->accept_subargs(1) if ($self->allow_restful_queries);
  
  # Disable editing on columns that aren't updatable:
  #$self->apply_except_colspec_columns($self->TableSpec->updatable_colspec => {
  #  editor => ''
  #});
  
  $self->apply_columns( $self->record_pk => { 
    no_column => \1, 
    no_multifilter => \1, 
    no_quick_search => \1 
  });
  
  # Hide any extra colspec columns that were only added for relationship
  # columns:
  #$self->apply_colspec_columns($self->TableSpec->added_relationship_column_relspecs,
  #  no_column => \1, 
  #  no_multifilter => \1, 
  #  no_quick_search => \1 
  #);
  
  $self->$orig(@_);
  
  # init primary columns:
  $self->primary_columns;
  
  # TODO: find out why this option doesn't work when applied via other, newer config mechanisms:
  $self->apply_store_config(
    remoteSort => \1
  );
  
  $self->apply_extconfig(
    remote_columns        => \1,
    loadMask          => \1,
    quicksearch_mode      => $self->quicksearch_mode,
    allow_set_quicksearch_mode  => $self->allow_set_quicksearch_mode ? \1 : \0
  );
  
  
  # This allows supplying custom BUILD code via a constructor:
  $self->onBUILD->($self) if ($self->onBUILD);
}

sub apply_colspec_columns {
  my $self = shift;
  my $colspec = shift;
  my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref
  
  my @colspecs = ( $colspec );
  @colspecs = @$colspec if (ref($colspec) eq 'ARRAY');

  my @columns = $self->TableSpec->get_colspec_column_names(@colspecs);
  my %apply = map { $_ => { %opt } } @columns;
  $self->apply_columns(%apply);
}

# Apply to all columns except those matching colspec:
sub apply_except_colspec_columns {
  my $self = shift;
  my $colspec = shift;
  my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref

  my @colspecs = ( $colspec );
  @colspecs = @$colspec if (ref($colspec) eq 'ARRAY');
  
  my @columns = $self->TableSpec->get_except_colspec_column_names(@colspecs);
  my %apply = map { $_ => { %opt } } @columns;
  $self->apply_columns(%apply);
}

sub delete_colspec_columns {
  my $self = shift;
  my @colspecs = (ref($_[0]) eq 'ARRAY') ? @{$_[0]} : @_;
  
  my @columns = $self->TableSpec->get_colspec_column_names(@colspecs);
  return $self->delete_columns(@columns);
}

# Delete all columns except those matching colspec:
sub delete_except_colspec_columns {
  my $self = shift;
  my @colspecs = (ref($_[0]) eq 'ARRAY') ? @{$_[0]} : @_;
  
  die "delete_except_colspec_columns: no colspecs supplied" unless (@colspecs > 0);
  
  my @columns = $self->TableSpec->get_except_colspec_column_names(@colspecs);
  return $self->delete_columns(@columns);
}

sub apply_except_colspec_columns_ordered {
  my $self = shift;
  my $indx = shift;
  my $colspec = shift;
  my %opt = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_; # <-- arg as hash or hashref

  my @colspecs = ( $colspec );
  @colspecs = @$colspec if (ref($colspec) eq 'ARRAY');
  
  my @columns = $self->TableSpec->get_except_colspec_column_names(@colspecs);
  my %apply = map { $_ => { %opt } } grep { exists $self->columns->{$_} } @columns;
  $self->apply_columns_ordered($indx,%apply);
}


sub get_read_records_Rs {
  my $self = shift;
  my $params = shift || $self->c->req->params;

  my $Rs = $self->_ResultSet;
  
  # Apply base Attrs:
  $Rs = $self->chain_Rs_req_base_Attr($Rs,$params);
  
  # Apply id_in search:
  $Rs = $self->chain_Rs_req_id_in($Rs,$params);
  
  # Apply explicit resultset:
  $Rs = $self->chain_Rs_req_explicit_resultset($Rs,$params);
  
  # Apply quicksearch:
  $Rs = $self->chain_Rs_req_quicksearch($Rs,$params);
  
  # Apply multifilter:
  $Rs = $self->chain_Rs_req_multifilter($Rs,$params);
  
  return $Rs;
}

sub read_records {
  my $self = shift;
  my $params = shift || $self->c->req->params;
  
  my $Rs = $self->get_read_records_Rs($params);
  
  # -- Github Issue #10 - SQLite-specific fix --
  local $Rs->result_source->storage->dbh
    ->{sqlite_see_if_its_a_number} = 1;
  # --
  
  $Rs = $self->_chain_search_rs($Rs,{},{rows => 1}) if ($self->single_record_fetch);
  
  # don't use Row objects
  my $Rs2 = $self->_chain_search_rs($Rs,undef, { result_class => 'DBIx::Class::ResultClass::HashRefInflator' });
    
  my $rows;
  try {
    my $start = [gettimeofday];
    
    # -----
    $rows = [ $self->rs_all($Rs2) ];
    #Hard coded munger for record_pk:
    foreach my $row (@$rows) { $row->{$self->record_pk} = $self->generate_record_pk_value($row); }
    $self->apply_first_records($Rs2,$rows,$params);
    # -----
    
    my $elapsed = tv_interval($start);
    $self->c->stash->{query_time} = sprintf('%.2f',$elapsed) . 's';
  }
  catch {
    my $err = shift;
    $self->handle_dbic_exception($err);
  };
  
  # Now calculate a total, for the grid to display the number of available pages
  my $total;
  try {
    $total = $self->rs_count($Rs2,$params);
  }
  catch {
    my $err = shift;
    local $append_exception_title = '(total count)';
    $self->handle_dbic_exception($err);
  };

  my $ret = {
    rows    => $rows,
    results => $total,
    query_time => $self->query_time
  };
  
  $self->calculate_column_summaries($ret,$Rs,$params) unless($self->single_record_fetch);
  
  return $ret;
}


# If optional param 'first_records_cond' was supplied, a second query (sub-set of the original)
# is ran and matching rows are moved to the top of the list of rows
sub apply_first_records {
  my ($self,$Rs,$rows,$params) = @_;
  return unless ($params && $params->{first_records_cond});
  
  my $cond = $self->param_decodeIf($params->{first_records_cond},{});
  return undef unless (keys %$cond > 0);
  
  my $first_rows = [ $self->_chain_search_rs($Rs,$cond)->all ];
  
  #Hard coded munger for record_pk:
  foreach my $row (@$first_rows) {
    $row->{$self->record_pk} = $self->generate_record_pk_value($row);
  }
  
  # concat both sets of rows together, with first_rows first:
  push @$first_rows, @$rows;
  
  # Remove duplicates:
  my %seen = ();
  @$first_rows = grep { !$seen{$_->{$self->record_pk}}++ } @$first_rows;
  
  # Shorten (truncate) to original length and replace original list with new list:
  @$rows = splice(@$first_rows, 0,@$rows);
}

sub rs_all { 
  my ($self, $Rs) = @_;
  my $want = wantarray;

  my @ret = ();
  try {
    @ret = $want ? $Rs->all : scalar $Rs->all
  }
  catch {
    my $err = shift;

    my $dbh = $Rs->result_source->schema->storage->dbh;
    my $LRL = $dbh->{LongReadLen} || 80;

    if($LRL == 80 && "$err" =~ /or LongReadLen too small/) {
      local $dbh->{LongReadLen} = 1024*256;
      warn join("\n",'','',
        '  Caught DBI LongTruncOk/LongReadLen exception and LongReadLen not configured --',
        "  Trying over with really large LongReadLen : $dbh->{LongReadLen}",
        '  You need to set this to a real/appropriate value for your database','',''
      );
      @ret = $want ? $self->rs_all($Rs) : scalar $self->rs_all($Rs)
    }
    else {
      die $err
    }
  };

  $want ? @ret : $ret[0]
}

sub rs_count { 
  my $self = shift;
  my $Rs2 = shift;
  my $params = shift || {};
  
  return 1 if ($self->single_record_fetch || $params->{no_total_count});
  
  # Optionally return the client supplied cached total:
  return $params->{cached_total_count}
    if($self->cache_total_count && exists $params->{cached_total_count});
  
  $self->c->stash->{query_count_start} = [gettimeofday];
  
  #return $self->rs_count_manual($Rs2);
  
  #return $self->rs_count_via_pager($Rs2);
  #return $self->rs_count_manual($Rs2);
  return $self->rs_count_with_fallbacks($Rs2);
}

sub rs_count_via_pager {
  my $self = shift;
  my $Rs2 = shift;
  return $Rs2->pager->total_entries;
}

# -- Alternate way to calculate the total count. The logic in 'pager->total_entries' just
# isn't entirely reliable still. Have been going back and forth between these two
# approaches, this time, I am leaving both in as separates functions (after writing this
# same code for the 3rd time at least!). The latest problem with the pager breaks with multiple
# having conditions on the same virtual column. The DBIC pager/total_entries code is 
# putting in the same sub-select, with AS, for each condition into the select which throws a 
# duplicate column db exception (MySQL).
# UPDATE: added options to fine-tune behaviors:
sub rs_count_manual {
  my $self = shift;
  my $Rs2 = shift;
  my %opts = @_;
  
  my $attr = {
    page => undef, 
    rows => undef,
    order_by => undef
  };
  
  unless($opts{no_strip_colums}) {
    my $cur_select = $Rs2->{attrs}->{select};
    my $cur_as = $Rs2->{attrs}->{as};
    
    # strip all columns except virtual columns (show as hashrefs)
    my ($select,$as) = ([],[]);
    for my $i (0..$#$cur_select) {
      next unless (ref $cur_select->[$i]);
      push @$select, $cur_select->[$i];
      push @$as, $cur_as->[$i];
    }
    
    $attr = { %$attr,
      select => $select,
      as => $as
    };
  }
  
  $Rs2 = $self->_chain_search_rs($Rs2,{},$attr);
  $Rs2 = $Rs2->as_subselect_rs unless ($opts{no_subselect});
  
  return $Rs2->count_literal if ($opts{count_literal});
  return $Rs2->count;
}

# 3rd alternative for getting the rs_count, tries several methods. This is not currently
# active, even though it is arguably the more reliable approach, because we don't want
# to hide problems by stopping the app from breaking. This is here mostly for future 
# reference and for debugging
sub rs_count_with_fallbacks {
  my $self = shift;
  my $Rs2 = shift;
  
  return try {
    try { 
      $Rs2->pager->total_entries
    } catch {
      warn RED . "\n\n" . $self->extract_db_error_from_exception($_) . CLEAR;
      warn RED.BOLD . "\n\n" .
        'COUNT VIA PAGER FAILED, FAILING BACK TO MANUAL COUNT' .
      "\n\n" . CLEAR;
      my $opt = {};
      try {
        $self->rs_count_manual($Rs2,%$opt)
      } catch {
        $opt->{no_strip_colums} = 1;
        warn RED . "\n\n" . $self->extract_db_error_from_exception($_) . CLEAR;
        warn RED.BOLD . "\n\n" .
          'COUNT VIA MANUAL FAILED, TRYING AGAIN WITHOUT STRIPPING COLUMNS ' . Dumper($opt) .
        "\n" . CLEAR;
        try {
          $self->rs_count_manual($Rs2,%$opt)
        } catch {
          $opt->{count_literal} = 1;
          warn RED . "\n\n" . $self->extract_db_error_from_exception($_) . CLEAR;
          warn RED.BOLD . "\n\n" .
            'COUNT VIA MANUAL FAILED, TRYING AGAIN WITH COUNT_LITERAL ' . Dumper($opt) .
          "\n" . CLEAR;
          $self->rs_count_manual($Rs2,%$opt)
        }
      };
    };
  } catch {
    warn RED . "\n\n" . $self->extract_db_error_from_exception($_) . CLEAR;
    warn RED.BOLD . "\n\n" .
      'FAILED TO GET TOTAL COUNT, GIVING UP' .
    "\n\n" . CLEAR;
    die $_;
  };
}

# --

after rs_count => sub { 
  my $self = shift;
  my $start = $self->c->stash->{query_count_start} || return undef;
  my $elapsed = tv_interval($start);
  $self->c->stash->{query_count_time} = sprintf('%.2f',$elapsed) . 's';
};


sub query_time {
  my $self = shift;
  my $qt = $self->c->stash->{query_time} || return undef;
  $qt .= '/' . $self->c->stash->{query_count_time} if ($self->c->stash->{query_count_time});
  return $qt;
}


sub calculate_column_summaries {
  my ($self,$ret,$Rs,$params) = @_;
  return unless ($params && $params->{column_summaries});
  
  my $sums = $self->param_decodeIf($params->{column_summaries},{});
  return unless (keys %$sums > 0);
  
  # -- Filter out summaries for cols that weren't requested in 'columns':
  my $req_cols = $self->c->stash->{req_columns}; #<-- previously calculated in get_req_columns():
  if($req_cols && @$req_cols > 0) {
    my %limit = map {$_=>1} @$req_cols;
    %$sums = map {$_=>$sums->{$_}} grep {$limit{$_}} keys %$sums;
  }
  # --
  
  my $select = [];
  my $as = [];
  
  my %extra = ();
  
  #foreach my $col (@{$Rs->{attrs}->{as}}) {
  foreach my $col (keys %$sums) {
    my $sum = $sums->{$col};
    if($sum) {
      my $dbic_name = $self->resolve_dbic_render_colname($col);
      my $sel = $self->get_col_summary_select($dbic_name,$sum);
      if($sel) {
        push @$select, $sel;
        push @$as, $col;
      }
      else { $extra{$col} = 'BadFunc!'; }
    }
  }
  
  try {
  
    my $agg_row;
    if($Rs->{attrs}->{having}) {
      # ---
      # Special support for queries with HAVING clause:
      #  This is heavily tied in with the custom building of
      #  'having' in this class and is slated to be refactored at
      #  some point... Conditions are converted from 'where' to
      #  'having' for virtual columns. For this case, we need to
      #  wrap in a subselect because the having relies on the AS
      #  within the select, which is replaced for the summary query.
      #  This special handling finally fixes Summary Functions when
      #  there is a virtual column setup in MultiFilters
      $agg_row = $self->_chain_search_rs($Rs,undef,{
        page => undef,
        rows => undef,
        order_by => undef,
      })->as_subselect_rs->search_rs(undef,{
        select => $select,
        as => $as,
      })->first or return;
      # ---
    }
    else {
      $agg_row = $self->_chain_search_rs($Rs,undef,{
        page => undef,
        rows => undef,
        order_by => undef,
        select => $select,
        as => $as
      })->first or return;
    }
    
    $ret->{column_summaries} = { $agg_row->get_columns, %extra };
  }
  catch {
    $self->c->log->error("$_");
    $ret->{column_summaries} = { map {$_=>'FuncError!'} keys %$sums };
  };
};

sub get_col_summary_select {
  my $self = shift;
  my $col = shift;
  my $func = shift;
  
  $func =~ s/^\s+//;
  $func =~ s/\s+$//;
  
  # Simple function name
  return { uc($func) => $col } if ($func =~ /^[a-zA-Z]+$/);
  
  # Replace macro string '{x}' with the column name
  $func =~ s/\{x\}/${col}/g;
  
  return \[ $func ];
  
  return undef;
}



# Applies base request attrs to ResultSet:
sub chain_Rs_req_base_Attr {
  my $self = shift;
  my $Rs = shift || $self->_ResultSet;
  my $params = shift || $self->c->req->params;
  
  $params = {
    start => 0,
    limit => 10000000,
    dir => 'asc',
    %$params
  };
  
  my $attr = {
    'select' => [],
    'as' => [],
    join => {},
    page => int($params->{start}/$params->{limit}) + 1,
    rows => $params->{limit}
  };
  
  my $columns = $self->get_req_columns;
  
  my $used_aliases = {};

  for my $col (@$columns) {
    my $dbic_name = $self->resolve_dbic_colname($col,$attr->{join});
    
    unless (ref $dbic_name) {
      my ($alias,$field) = split(/\./,$dbic_name);
      my $prefix = $col;
      
      $prefix =~ s/${field}$//;
      $used_aliases->{$alias} = {} unless ($used_aliases->{$alias});
      $used_aliases->{$alias}->{$prefix}++ unless($alias eq 'me');
      my $count = scalar(keys %{$used_aliases->{$alias}});
      # automatically set alias for duplicate joins:
      $dbic_name = $alias . '_' . $count . '.' . $field if($count > 1);
    }
    
    push @{$attr->{'select'}}, $dbic_name;
    push @{$attr->{'as'}}, $col;
  }
  
  if ($params->{sort} and $params->{dir}) {
    my $sort = lc($params->{sort});
    my $sort_name = $self->resolve_dbic_render_colname($sort,$attr->{join});
    if (ref $sort_name eq 'HASH') {
      die "Can't sort by column if it doesn't have an SQL alias"
        unless exists $sort_name->{-as};
      $sort_name= $sort_name->{-as};
    }
    $attr->{order_by} = { '-' . $params->{dir} => $sort_name } ;
  }

  return $self->_chain_search_rs($Rs,{},$attr);
}

sub resolve_dbic_colname {
  my $self = shift;
  return $self->TableSpec->resolve_dbic_colname(@_);
}


sub resolve_dbic_render_colname {
  my $self = shift;
  my $name = shift;
  my $join = shift || {};
  
  $self->c->stash->{dbic_render_colnames} = $self->c->stash->{dbic_render_colnames} || {};
  my $h = $self->c->stash->{dbic_render_colnames};
  
  my $get_render_col = 1;
  $h->{$name} = $h->{$name} || $self->resolve_dbic_colname($name,$join,$get_render_col);
  
  return $h->{$name};
}

has 'always_fetch_columns', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return [] unless ($self->always_fetch_colspec);
  return [ $self->TableSpec->get_colspec_column_names(
    $self->TableSpec->always_fetch_colspec->colspecs
  )];
}, isa => 'ArrayRef';
sub all_always_fetch_columns { uniq( @{(shift)->always_fetch_columns} ) }

sub get_req_columns {
  my $self = shift;
  my $params = shift || $self->c->req->params;
  my $param_name = shift || 'columns';
  
  my $columns = $params;
  $columns = $self->param_decodeIf($params->{$param_name},[]) if (ref($params) eq 'HASH');
  
  die "get_req_columns(): bad options" unless(ref($columns) eq 'ARRAY');
  
  $self->c->stash->{req_columns} = [@$columns];
  
  # ---
  # If no columns were supplied by the client, add all the columns from
  # include_relspec
  # TODO: move column request logic that's currently only in AppGrid2 to a 
  # plugin/store where it can be used by other js modules like dataview
  unless(@$columns > 0) {
    # new/simple way:
    @$columns = grep { $_ ne $self->record_pk } $self->column_name_list;
    # old, more complex (and slow) approach:
    #push @$columns, $self->TableSpec->get_colspec_column_names(
    #  $self->TableSpec->include_colspec->colspecs
    #);
    ## Limit to current real/valid columns according to DataStore2:
    #my %cols_indx = map {$_=>1} $self->column_name_list;
    #@$columns = grep { $cols_indx{$_} } @$columns;
  }
  # ---
  
  push @$columns, $self->all_always_fetch_columns;
  
  # Make sure the supplied sort column is included (needed for sorting on a *hidden* virtual
  # columns, including mutli and m2m relationship columns)
  push @$columns, $params->{sort} if ($params->{sort});
  
  my @exclude = ( $self->record_pk, 'loadContentCnf' );
  
  push @$columns, @{$self->primary_columns};
  
  my @req_fetch = ();
  foreach my $col (grep {defined $self->columns->{$_}} @$columns) {
    my $req = $self->columns->{$col}->required_fetch_columns or next;
    push @req_fetch, grep { defined $self->columns->{$_} } @$req;
  }
  push @$columns, @req_fetch;
  
  foreach my $col (@$columns) {
    my $column = $self->columns->{$col};
    push @exclude, $col if ($column->{no_fetch});
  }
  
  uniq($columns);
  my %excl = map { $_ => 1 } @exclude;
  @$columns = grep { !$excl{$_} } @$columns;
  
  return $columns;
}


# Applies id_in filter to ResultSet:
sub chain_Rs_req_id_in {
  my $self = shift;
  my $Rs = shift || $self->_ResultSet;
  my $params = shift || $self->c->req->params;
  
  my $id_in = $self->param_decodeIf($params->{id_in}) or return $Rs;
  
  return $Rs if (ref $id_in and ! ref($id_in) eq 'ARRAY');
  $id_in = [ $id_in ] unless (ref $id_in);
  
  # TODO: second form below doesn't work, find out why...
  return $self->_chain_search_rs($Rs,{ '-or' => [ map { $self->record_pk_cond($_) } @$id_in ] });
  
  ## If there is more than one primary column, we have to construct the condition completely 
  ## different:
  #return $self->_chain_search_rs($Rs,{ '-or' => [ map { $self->record_pk_cond($_) } @$id_in ] })
  #  if (@{$self->primary_columns} > 1);
  #  
  ## If there is really only one primary column we can use '-in' :
  #my $col = $self->TableSpec->resolve_dbic_colname($self->primary_columns->[0]);
  #return $self->_chain_search_rs($Rs,{ $col => { '-in' => $id_in } });
}


# Applies additional explicit resultset cond/attr to ResultSet:
sub chain_Rs_req_explicit_resultset {
  my $self = shift;
  my $Rs = shift || $self->_ResultSet;
  my $params = shift || $self->c->req->params;
  
  my $cond = $self->param_decodeIf($params->{resultset_condition},{});
  my $attr = $self->param_decodeIf($params->{resultset_attr},{});
  
  
  ##
  ## TODO: make this code handle more cases
  ## This code converts [[ 'foo' ]] into \[ 'foo' ] and is needed because the later cannot
  ## be expressed in JSON. This allows the client to send a literal col name
  if(ref($attr->{select}) eq 'ARRAY') {
    my @new;
    foreach my $sel (@{$attr->{select}}) {
      if(ref($sel) eq 'ARRAY' and scalar @$sel == 1 and ref($sel->[0]) eq 'ARRAY') {
        push @new, \[ $sel->[0]->[0] ];
      }
      else {
        push @new,$sel;
      }
    }
    @{$attr->{select}} = @new;
  }
  ##
  ##
  
  return $self->_chain_search_rs($Rs,$cond,$attr);
}


# Applies Quick Search to ResultSet:
sub chain_Rs_req_quicksearch {
  my $self = shift;
  my $Rs = shift || $self->_ResultSet;
  my $params = shift || $self->c->req->params;

  delete $params->{qs_query} if (defined $params->{qs_query} and $params->{qs_query} eq '');
  my $query = $params->{qs_query} or return $Rs;

  my $fields = $self->param_decodeIf($params->{qs_fields},[]);
  return $Rs unless (@$fields > 0);

  my $attr = { join => {} };

  my $mode = $params->{quicksearch_mode} || $self->quicksearch_mode;
  $mode = $self->quicksearch_mode unless ($self->allow_set_quicksearch_mode);

  my @search = ();
  foreach my $field (@$fields) {
    my $cond = $self->_resolve_quicksearch_condition(
      $field, $query, { mode => $mode, joinref => $attr->{join} }
    ) or next; #<-- skip for undef (see below)
    push @search, $cond;
  }

  # If no search conditions have been populated at all it means the query
  # failed pre-validation for all active columns. We need to simulate
  # a condition which will return no rows
  unless(scalar(@search) > 0) {
    # Simple dummy condition that will always be false to force 0 results
    return $Rs->search_rs(\'1 = 2');
  }

  return $self->_chain_search_rs($Rs,{ '-or' => \@search },$attr);
}


sub _resolve_quicksearch_condition {
  my ($self, $field, $query, $opt) = @_;

  my $cnf  = $self->get_column($field) or die "field/column '$field' not found!";
  my $join = $opt->{joinref} or die "missing opt/ref 'joinref'";
  my $mode = $opt->{mode} or die "missing opt 'mode'";

  # Force to exact mode via optional TableSpec column cnf override:
  $mode = 'exact' if (
    exists $cnf->{quick_search_exact_only}
    && jstrue($cnf->{quick_search_exact_only})
  );

  my $dtype    = $cnf->{broad_data_type} || 'text';
  my $dbicname = $self->resolve_dbic_colname($field,$join);

  # For numbers, force to 'exact' mode and discard (return undef) for queries
  # which are not numbers (since we already know they will not match anything). 
  # This is also now safe for PostgreSQL which complains when you try to search
  # on a numeric column with a non-numeric value:
  if ($dtype eq 'integer') {
    return undef unless $query =~ /^[+-]*[0-9]+$/;
    $mode = 'exact';
  }
  elsif ($dtype eq 'number') {
    return undef unless (
      looks_like_number( $query )
    );
    $mode = 'exact';
  }

  # Special-case: pre-validate enums (Github Issue #56)
  my $enumVh = $cnf->{enum_value_hash};
  if ($enumVh) {
    return undef unless ($enumVh->{$query});
    $mode = 'exact';
  }

  # New for GitHub Issue #97
  my $strf = $cnf->{search_operator_strf};
  my $s = $strf ? sub { sprintf($strf,shift) } : sub { shift };

  # 'text' is the only type which can do a LIKE (i.e. sub-string)
  return $mode eq 'like' 
    ? { $dbicname => { $s->('like') => join('%','',$query,'') } }
    : { $dbicname => { $s->('=')    => $query } };
}



our ($needs_having,$dbf_active_conditions);

# Applies multifilter search to ResultSet:
sub chain_Rs_req_multifilter {
  my $self = shift;
  my $Rs = shift || $self->_ResultSet;
  my $params = shift || $self->c->req->params;
  
  my $multifilter = $self->param_decodeIf($params->{multifilter},[]);
  my $multifilter_frozen = $self->param_decodeIf($params->{multifilter_frozen},[]);
  @$multifilter = (@$multifilter_frozen,@$multifilter);
  
  return $Rs unless (scalar @$multifilter > 0);
  
  # Localize HAVING tracking global variables. These will be set within the call chain
  # from 'multifilter_to_dbf' called next;
  local $needs_having = 0;
  local $dbf_active_conditions = [];
  
  my $attr = { join => {} };
  my $cond = $self->multifilter_to_dbf($multifilter,$attr->{join}) || {};
  
  return $self->_chain_search_rs($Rs,$cond,$attr) unless ($needs_having);

  # If we're here, '$needs_having' was set to true and we need to convert the
  # *entire* query to use HAVING instead of WHERE to be sure we correctly handle
  # any possible interdependent hierachy of '-and'/'-or' conditions. This means that 
  # one or more of our columns are virtual, and one or more of them are contained 
  # within the multifilter search, which effects the entire multifilter query.
  #
  # To convert from WHERE to HAVING we need to convert ALL columns to act like
  # virtual columns with '-as' and then transform the conditions to reference those 
  # -as/alias names. Also, we need to make sure that each condition exists in the 
  # SELECT clause of the query for it to be able to work as a HAVING condition, 
  # because HAVING references the declared AS name from the SELECT, while WHERE is 
  # based on real/existing column names of the schema. Note that we're doing this 
  # because we have to; when there are no virtual columns in the condition we do
  # a nomal WHERE which provides better performance. 
  #
  # TODO: investigate teasing out exactly which conditions really have to use HAVING 
  # and which others could continue to use WHERE without harming the overall effective 
  # result set. This could get very complicated because the condition data structure
  # supports an arbitrary structure. It is doable, but it depends on the real-world
  # performance differences to determine how important that extra layer of logic would
  # really be.
  
  #
  # Step 1/3 - add missing selects
  #
  
  # sort virtual selects to the end for priority in name collisions 
  # (can happen with multi-rels with the same name as a column):
  @$dbf_active_conditions = sort { !(ref $b->{select}) cmp (ref $a->{select}) } @$dbf_active_conditions;
  

  # Collapse uniq needed col/cond names into a Hash:
  my %needed_selects = map { $_->{name} => $_ } @$dbf_active_conditions;

  # ---- Hack/fix for searching non-active virtual columns:
  # the problem with this $dbf_active_conditions global/local design is that
  # it will not contain *virtual* columns that are not being selected in
  # active columns. This breaks virtual columns from being able to be filtered
  # while not active. To solve this we just need to manually resolve the column
  # into its proper dbic column select name:
  for my $fname (keys %needed_selects) {
    my $hash = $needed_selects{$fname};
    $hash->{select} = $self->resolve_dbic_colname($hash->{field},{});
  }
  # ----

  my $cur_select = $Rs->{attrs}->{select};
  my $cur_as = $Rs->{attrs}->{as};
  
  # prune out all columns that are already being selected:
  exists $needed_selects{$_} and delete $needed_selects{$_} 
    for (map { try{$_->{-as}} || $_ } @$cur_select);
  
  # Add all leftover needed selects. These are column/cond/select names that are being
  # used in one or more conditions but are not already being selected. Unlike WHERE, all
  # HAVING conditions must be contained in the SELECT clause:
  push(@$cur_select,$needed_selects{$_}->{select}) 
    and push(@$cur_as,$needed_selects{$_}->{field}) for (keys %needed_selects);
  
  #
  # Step 2/3 - transform selects:
  #
  
  my %virtuals = (); #<-- new for Github Issue #51
  my %map = ();
  my ($select,$as) = ([],[]);
  for my $i (0..$#$cur_select) {
    delete $needed_selects{$cur_select->[$i]} if (exists $needed_selects{$cur_select->[$i]});
    push @$as, $cur_as->[$i];
    if (ref $cur_select->[$i]) {
      # Already a virtual column, no changes:
      push @$select, $cur_select->[$i];
      # new for Github Issue #51:
      $virtuals{$cur_as->[$i]} = $self->_extract_virtual_subselect_ref($cur_select->[$i]);
      next;
    }
    
    push @$select, { '' => $cur_select->[$i], '-as' => $cur_as->[$i] };
    
    # Track the mapping so we can walk/replace the cond in the next step:
    $map{$cur_select->[$i]} = $cur_as->[$i];
  }
  
  #
  # Step 3/3 - transform conditions:
  #
  
  # Deep remap all condition values from WHERE type to HAVING (AS) type:
  my ($having) = dmap { ref $_ eq 'HASH' ?
    # wtf? dmap doesn't act on keys, so we have to do it ourselves.
    # We only care about keys, anyway
    { map { defined $_ && exists $map{$_} ? $map{$_} : $_ } %$_ } :
      $_
  } $cond;
  
  # ---
  # Temporary implementation for Github Issue #51
  # Here we are doing yet another transformation step, which is to duplicate the full sub-select
  # for our virtual columns within the condition. This was needed for PostgreSQL support which
  # was discussed at length within the comments of Github Issue #51. Since we're doing it this 
  # way now, we can use a normal WHERE clause instead of a HAVING clause. I'm still not certain
  # this represents the final implementation, and there are lots of entanglements and potential
  # points-of-failure (which are not yet under test coverage) so for now this is being done using
  # the least code changes possible. If this is finalized, a refactor pass will remove a *lot* of
  # code and machinery that serves no purpose if we are not transforming into a HAVING at all...
  #
  my $virtual_where = 1; #<-- set to 0 to revert to HAVING codepath
  if ($virtual_where) {
    $cond = $self->_recurse_transform_condition(clone($cond),\%virtuals);
    return $self->_chain_search_rs($Rs,{},{ %$attr,
      where => $cond,
      select => $select,
      as => $as
    });
  }
  else {
    # This is the old code which uses HAVING via alias identifiers. This is being left in for 
    # now as an active code block (rather than removed/commented out) to make it easier to 
    # come back to later. We may want to still do this for RDBMS'es which support this (at 
    # least MySQL and SQLite do, and at least PostgreSQL does not). But, the question will be
    # to ask if there is even a performance advantage of doing this, and if so, when, how, etc
    return $self->_chain_search_rs($Rs,{},{ %$attr,
      group_by => [ map { 'me.' . $_ } @{$self->primary_columns} ], #<-- safe group_by
      having => $having,
      select => $select,
      as => $as
    });
  }
  # ---
}


# This machinery was added for Github Issue #51 (see earlier comments)
sub _extract_virtual_subselect_ref {
  my ($self, $el) = @_;
  my $val = $el->{''} or die "Expected empty-string hashkey";
  # We're handling just 2 cases which know about in advance, virtual columns
  # and multi-relationship columns:
  $val = ref($val) eq 'ARRAY' ? $val->[0] : $val;
  return ref $val ? $val : \$val;
}

sub sql_maker { (shift)->ResultSource->schema->storage->sql_maker }

sub _recurse_transform_condition {
  my ($self, $val, $remap) = @_;

  return $val unless ($val && ref $val);

  if(ref($val) eq 'ARRAY') {
    @$val = map {
      $self->_recurse_transform_condition($_,$remap)
    } @$val;
  }
  elsif(ref($val) eq 'HASH') {
    if(scalar(keys %$val) == 1) {
      my ($k,$v) = (%$val);
      # This is the location where we are actually 
      # changing something in the structure:
      return &_binary_op_fuser(
        $self->sql_maker,
        $remap->{$k},
        $self->_recurse_transform_condition($v,$remap)
      ) if($remap->{$k});
    }

    %$val = map {
      $_ => $self->_recurse_transform_condition($val->{$_},$remap)
    } (keys %$val);
  }

  return $val;
}

# -- Function (and disclaimer) provided by ribasushi for Github Issue #51 --
###############################################################
#        DO NOT COPY THIS UNDER ANY CIRCUMSTANCES
#  THIS IS A TEMPORARY HACK AND WILL BE BROKEN BY THE MAINTAINERS
#          POSSIBLY BEFORE THE END OF THIS YEAR
###############################################################
sub _binary_op_fuser {
  my ($sm, $l, $r) = @_;

  my ($lsql, @lbind) = $sm->_recurse_where($l);

  local $sm->{_nested_func_lhs} = {};
  my ($rsql, @rbind) = $sm->_recurse_where({ "\0" => $r });

  my ($ql, $qr) = $sm->_quote_chars;
  $rsql =~ s/ (\Q$ql\E)? \0 (\Q$qr\E)? //gx;

  $rsql =~ s/ \A \s* \( (.+?) \) \s* \z /$1/sx;

  return \[
    "$lsql $rsql",
    @lbind,
    @rbind
  ];
}
###############################################################
#        DO NOT COPY THIS UNDER ANY CIRCUMSTANCES
#  THIS IS A TEMPORARY HACK AND WILL BE BROKEN BY THE MAINTAINERS
#          POSSIBLY BEFORE THE END OF THIS YEAR
###############################################################
# --


# Common proxy for calls to $Rs->search_rs(...)
sub _chain_search_rs {
  my ($self, $Rs, $cond, $attr) = @_;

  # --
  # Convert {} joins to undef - this prevents ResultSet unititialized warnings when:
  #  join => { rel1 => { rel2 => {} } }
  # becomes:
  #  join => { rel1 => { rel2 => undef } }
  # (See DBIx::Class::ResultSet::_calculate_score() and related code)
  $attr = {
    %$attr,
    join => $self->_recurse_clean_empty_hashrefs($attr->{join})
  } if ($attr->{join});
  # --

  $Rs->search_rs($cond,$attr)
}

sub _recurse_clean_empty_hashrefs {
  my ($self, $val) = @_;

  if($val && ref($val) eq 'HASH') {
    return (scalar keys(%$val) > 0)
      ? { map { $_ => $self->_recurse_clean_empty_hashrefs($val->{$_}) } keys(%$val) }
      : undef
  }
  else {
    return $val
  }
}


sub multifilter_to_dbf {
  my $self = shift;
  my $multi = clone(shift);
  my $join = shift || {};
  
  return $self->multifilter_to_dbf({ '-and' => $multi },$join) if (ref($multi) eq 'ARRAY');
  
  die RED.BOLD."Invalid multifilter:\n" . Dumper($multi).CLEAR unless (
    ref($multi) eq 'HASH' and
    keys %$multi == 1
  );
  
  my ($f,$cond) = (%$multi);
  if($f eq '-and' or $f eq '-or') {
    die "-and/-or must reference an ARRAY/LIST" unless (ref($cond) eq 'ARRAY');
    my @list = map { $self->multifilter_to_dbf($_,$join) } @$cond;
    return { $f => \@list };
  }
  
  # -- relationship column:
  my $is_cond = (
    ref($cond) eq 'HASH' and
    exists $cond->{is}
  ) ? 1 : 0;
  
  my $column = $self->get_column($f) || {};
  $f = $column->{query_search_use_column} || $f;
  $f = $column->{query_id_use_column} || $f if ($is_cond);
  # --
  
  my $dbfName = $self->resolve_dbic_colname($f,$join)
    or die "Client supplied Unknown multifilter-field '$f' in Ext Query!";
  
  # Set the localized '$needs_having' flag to tell our caller to convert
  # from WHERE to HAVING if this condition is based on a virtual column: 
  $needs_having = 1 if(
    ref $dbfName eq 'HASH' and 
    exists $dbfName->{-as} and 
    exists $dbfName->{''}
  );
  
  return $self->multifilter_translate_cond($cond,$dbfName,$f);
}



my %mf_op_alias = (
  'is'                    => '=',
  'equal to'              => '=',
  'is equal to'           => '=',
  'exactly'               => '=',
  'before'                => '<',
  'less than'             => '<',
  'greater than'          => '>',
  'after'                 => '>',
  'not equal to'          => '!=',
  'is not equal to'       => '!=',
  "doesn't contain"       => 'not_contain',
  'starts with'           => 'starts_with',
  'ends with'             => 'ends_with',
  "doesn't start with"    => 'not_starts_with',
  "doesn't end with"      => 'not_ends_with',
  'ends with'             => 'ends_with',

  'is null'               => 'is_null',
  'is empty'              => 'is_empty',
  'is not null'           => 'not_null',
  'is not empty'          => 'not_empty',
  'is null or empty'      => 'null_or_empty',
  'is not null or empty'  => 'not_null_or_empty',

  'null/empty status'     => 'null_empty_status'
);
# This will deep recurse if there there a circular refs in %mf_op_alias above
sub _mf_resolve_op {
  my ($self, $op) = @_;
  $mf_op_alias{$op} ? $self->_mf_resolve_op($mf_op_alias{$op}) : $op;
}

sub _mf_get_cond {
  my ($self,$select,$op,$val,$strf) = @_;

  $op = $self->_mf_resolve_op($op);

  # New for GitHub Issue #97
  my $s = $strf ? sub { sprintf($strf,shift) } : sub { shift };

  my $cond;

  if($op eq 'contains') {
    $cond = $self->_op_fuse($select => { $s->('like') => join('','%',$val,'%') });
  }
  elsif($op eq 'starts_with') {
    $cond = $self->_op_fuse($select => { $s->('like') => join('',$val,'%') });
  }
  elsif($op eq 'ends_with') {
    $cond = $self->_op_fuse($select => { $s->('like') => join('','%',$val) });
  }
  elsif($op eq 'not_contain') {
    $cond = { -or => [ # NOT LIKE -OR- NULL
      $self->_op_fuse($select => { $s->('not like') => join('','%',$val,'%') }),
      # Note: we do not pass the operator for undef through the strf because it
      # is treated special by SQLA - becomes "IS NULL" etc... (#97)
      $self->_op_fuse($select => { '=' => undef }),
    ]};
  }
  elsif($op eq 'not_starts_with') {
    $cond = { -or => [ # NOT LIKE -OR- NULL
      $self->_op_fuse($select => { $s->('not like') => join('',$val,'%') }),
      $self->_op_fuse($select => { '=' => undef }),
    ]};
  }
  elsif($op eq 'not_ends_with') {
    $cond = { -or => [ # NOT LIKE -OR- NULL
      $self->_op_fuse($select => { $s->('not like') => join('','%',$val) }),
      $self->_op_fuse($select => { '=' => undef }),
    ]};
  }
  elsif($op eq 'is_null') {
    $cond = $self->_op_fuse($select => { '=' => undef });
  }
  elsif($op eq 'is_empty') {
    $cond = $self->_op_fuse($select => { $s->('=') => '' });
  }
  elsif($op eq 'not_null') {
    $cond = $self->_op_fuse($select => { '!=' => undef });
  }
  elsif($op eq 'not_empty') {
    $cond = $self->_op_fuse($select => { $s->('!=') => '' });
  }
  elsif($op eq 'null_or_empty') {
    $cond = { -or => [
      $self->_op_fuse($select => { '=' => undef }),
      $self->_op_fuse($select => { $s->('=') => '' })
    ]};
  }
  elsif($op eq 'not_null_or_empty') {
    $cond = { -and => [
      $self->_op_fuse($select => { '!=' => undef }),
      $self->_op_fuse($select => { $s->('!=') => '' })
    ]};
  }
  elsif($op eq 'null_empty_status') {
    # Re-call with with the val as the op:
    $cond = $self->_mf_get_cond($select, $val);
  }
  else {
    $cond = $self->_op_fuse($select => { $op => $val });
  }

  $cond
}

sub _op_fuse {
  my $self = shift;
  &_binary_op_fuser($self->sql_maker, @_)
}


# -- multifilter_translate_cond()
#    - refactored for #88 and #89
#    - previously modified for #69 and #51
sub multifilter_translate_cond {
  my $self = shift;
  my $cond = shift;
  my $dbfName = shift;
  my $field = shift;
  my $column = try{$self->get_column($field)} || {};

  # If we're a virtual column:
  my ($select,$as) = ((ref $dbfName||'') eq 'HASH' && $dbfName->{-as} && $dbfName->{''})
    ? ($dbfName->{''} => $dbfName->{-as} )
    : ($dbfName       => $dbfName        );

  # -- TODO - this is legacy and needs to be investigated and removed
  # Track in localized global:
  push @$dbf_active_conditions, {
    name => $as,
    field => $field, 
    select => clone($dbfName)
  };
  # --
  
  # There should be exactly 1 key/value:
  die "invalid multifilter condition: must have exactly 1 key/value pair:\n" . Dumper($cond) 
    unless (keys %$cond == 1);
    
  my ($k,$v) = (%$cond);
  
  $v = $self->inflate_multifilter_date($v) if(
    $column->{multifilter_type} &&
    $column->{multifilter_type} =~ /^date/
  );

  # New for GitHub #97 - pass in optional new search_operator_strf param
  return $self->_mf_get_cond($select, $k, $v,$column->{search_operator_strf});
}



sub multifilter_date_getKeywordDt {
  my $self = shift;
  my $keyword = shift;

  $keyword =~ s/\s*//g; #<-- stip whitespace from the keyword
  $keyword = lc($keyword); #<-- lowercase it

  my $dt = DateTime->now( time_zone => 'local' );

  my $kw = $keyword;
  if($kw eq 'now') { return $dt }
  
  elsif($kw eq 'thisminute') { return DateTime->new(
    year  => $dt->year,
    month  => $dt->month,
    day    => $dt->day,
    hour  => $dt->hour,
    minute  => $dt->minute,
    second  => 0,
    time_zone => 'local'
  )}
  
  elsif($kw eq 'thishour') { return DateTime->new(
    year  => $dt->year,
    month  => $dt->month,
    day    => $dt->day,
    hour  => $dt->hour,
    minute  => 0,
    second  => 0,
    time_zone => 'local'
  )}
  
  elsif($kw eq 'thisday') { return DateTime->new(
    year  => $dt->year,
    month  => $dt->month,
    day    => $dt->day,
    hour  => 0,
    minute  => 0,
    second  => 0,
    time_zone => 'local'
  )}
  
  # same as thisday:
  elsif($kw eq 'today') { return DateTime->new(
    year  => $dt->year,
    month  => $dt->month,
    day    => $dt->day,
    hour  => 0,
    minute  => 0,
    second  => 0,
    time_zone => 'local'
  )}
  
  elsif($kw eq 'thisweek') { 
    my $day = $dt->day_of_week;
    #$day++; $day = 1 if ($day > 7); #<-- shift day 1 from Monday to Sunday
    $dt = $dt->subtract( days => ($day - 1) );
    return DateTime->new(
      year  => $dt->year,
      month  => $dt->month,
      day    => $dt->day,
      hour  => 0,
      minute  => 0,
      second  => 0,
      time_zone => 'local'
    );
  }
  
  elsif($kw eq 'thismonth') { return DateTime->new(
    year  => $dt->year,
    month  => $dt->month,
    day    => 1,
    hour  => 0,
    minute  => 0,
    second  => 0,
    time_zone => 'local'
  )}
  
  elsif($kw eq 'thisquarter') {
    my $month = $dt->month;
    my $subtract = 0;
    if($month > 0 && $month <= 3) {
      $subtract = $month - 1;
    }
    elsif($month > 3 && $month <= 6) {
      $subtract = $month - 4;
    }
    elsif($month > 6 && $month <= 9) {
      $subtract = $month - 7;
    }
    else {
      $subtract = $month - 10;
    }
    
    $dt = $dt->subtract( months => $subtract );
    return DateTime->new(
      year  => $dt->year,
      month  => $dt->month,
      day    => 1,
      hour  => 0,
      minute  => 0,
      second  => 0,
      time_zone => 'local'
    );
  }
  
  elsif($kw eq 'thisyear') { return DateTime->new(
    year  => $dt->year,
    month  => 1,
    day    => 1,
    hour  => 0,
    minute  => 0,
    second  => 0,
    time_zone => 'local'
  )}
  
  return undef;
}

# This is a clone of the JavaScript logic in the function parseRelativeDate() in the plugin
# class Ext.ux.RapidApp.Plugin.RelativeDateTime. While it is not ideal to have to reproduce
# this and have to maintain in both Perl and JavaScript simultaneously, this is the most
# straightforward way to achive the desired functionality. This is because these relative
# dates have to be inflated at query/request time, and MultiFilters wasn't designed with that
# in mind. To do this in the client side, multifilters would need significant modifications
# to get it to munge its filters on every request, which is was not designed to do.
sub inflate_multifilter_date {
  my $self = shift;
  my $v = shift;
  
  my $dt = $self->multifilter_date_getKeywordDt($v);
  return $dt->ymd . ' ' . $dt->hms if ($dt);
  
  my $orig_v = $v;

  my @parts = split(/[\-\+]/,$v);
  if(scalar @parts > 1 && length $parts[0] > 0) {
    #If we are here then it means a custom start keyword was specified:
    my $keyword = $parts[0];
    $v =~ s/^${keyword}//; #<-- strip out the keyword from the string value
    $keyword =~ s/\s*//g; #<-- stip whitespace from the keyword
    $keyword = lc($keyword); #<-- lowercase it
    
    $dt = $self->multifilter_date_getKeywordDt($keyword);
  }
  else {
    $dt = $self->multifilter_date_getKeywordDt('now');
  }
  
  my $sign = substr($v,0,1);
  return $orig_v unless ($dt && ($sign eq '-' || $sign eq '+'));
  
  my $str = substr($v,1);
  
  # Strip whitespace and commas:
  $str =~ s/[\s\,]*//g;
  
  $str = lc($str);
  
  @parts = ();
  while(length $str) {
    my ($num,$unit);
    my $match;
    ($match) = ($str =~ /^(\d+)/); $str =~ s/^(\d+)//; $num  = $match;
    ($match) = ($str =~ /^(\D+)/); $str =~ s/^(\D+)//; $unit = $match;
    
    #custom support for "weeks":
    if($unit eq 'w' || $unit eq 'week' || $unit eq 'weeks' || $unit eq 'wk' || $unit eq 'wks') {
      $unit = 'days';
      $num = $num * 7;
    }
    
    #custom support for "quarters":
    if($unit eq 'q' || $unit eq 'quarter' || $unit eq 'quarters' || $unit eq 'qtr' || $unit eq 'qtrs') {
      $unit = 'months';
      $num = $num * 3;
    }
    
    push @parts, { num => $num, unit => $unit } if ($num && $unit);
  }
  
  return $v unless (@parts > 0);
  
  my $method = ($sign eq '-') ? 'subtract' : 'add';
  
  my $map = $self->inflate_multifilter_date_unit_map;
  my $count = 0;
  foreach my $part (@parts) {
    my $interval = $map->{$part->{unit}} or next;
    my $newDt = $dt->$method( $interval => $part->{num} ) or next;
    $count++;
    $dt = $newDt;
  }
  
  return $orig_v unless ($count);
  
  return $dt->ymd . ' ' . $dt->hms;
}

# Equiv to Ext.ux.RapidApp.Plugin.RelativeDateTime.unitMap
has 'inflate_multifilter_date_unit_map', is => 'ro', default => sub {{
  
  y      => 'years',
  year    => 'years',
  years    => 'years',
  yr      => 'years',
  yrs      => 'years',
  
  m      => 'months',
  mo      => 'months',
  month    => 'months',
  months    => 'months',
  
  d      => 'days',
  day      => 'days',
  days    => 'days',
  dy      => 'days',
  dys      => 'days',
  
  h      => 'hours',
  hour    => 'hours',
  hours    => 'hours',
  hr      => 'hours',
  hrs      => 'hours',
  
  i      => 'minutes',
  mi      => 'minutes',
  min      => 'minutes',
  mins    => 'minutes',
  minute    => 'minutes',
  minutes    => 'minutes',
  
  s      => 'seconds',
  sec      => 'seconds',
  secs    => 'seconds',
  second    => 'seconds',
  second    => 'seconds'
}};

has 'is_virtual_source', is => 'ro', lazy => 1, default => sub {
  my $self = shift;
  return  (
    $self->ResultClass->result_source_instance->can('is_virtual') &&
    $self->ResultClass->result_source_instance->is_virtual
  );
}, isa => 'Bool';

has 'DataStore_build_params' => ( is => 'ro', isa => 'HashRef', default => sub {{}} );
before DataStore2_BUILD => sub {
  my $self = shift;
  
  my @store_fields = map {{ name => $_ }} uniq(
    $self->TableSpec->updated_column_order,
    'loadContentCnf', #<-- specific to AppGrid2
    $self->record_pk
  );
  
  my $store_params = {
    store_autoLoad => 1,
    reload_on_save => 0,
    remoteSort => \1,
    store_fields => \@store_fields
  };
  
  $store_params->{create_handler}  = RapidApp::Handler->new( scope => $self, method => '_dbiclink_create_records' ) if (
    defined $self->creatable_colspec and 
    not $self->can('create_records')
  );
  
  $store_params->{update_handler}  = RapidApp::Handler->new( scope => $self, method => '_dbiclink_update_records' ) if (
    defined $self->updatable_colspec and 
    not $self->can('update_records')
  );
  
  $store_params->{destroy_handler}  = RapidApp::Handler->new( scope => $self, method => '_dbiclink_destroy_records' ) if (
    defined $self->destroyable_relspec and 
    not $self->can('destroy_records')
  );
  
  # New: Override to globally disable create/destroy for virtual sources:
  if($self->is_virtual_source) {
    exists $store_params->{create_handler}  && delete $store_params->{create_handler};
    exists $store_params->{destroy_handler} && delete $store_params->{destroy_handler};
    $self->apply_flags( can_create  => 0 );
    $self->apply_flags( can_destroy => 0 );
  }
  
  # merge this way to make sure the opts get set, but yet still allow
  # the opts to be specifically overridden DataStore_build_params attr
  # is defined but with different params
  %{$self->DataStore_build_params} = ( %$store_params, %{$self->DataStore_build_params} );
};



# convenience method: prints the primary keys of a Row object
# just used to print info to the screen during CRUD ops below
sub get_Row_Rs_label {
  my $self = shift;
  my $Row = shift;
  my $verbose = shift;
  
  if($Row->isa('DBIx::Class::ResultSet')) {
    my $Rs = $Row;
    my $str = ref($Rs) . ' [' . $Rs->count . ' rows]';
    return $str unless ($verbose);
    $str .= ':';
    $str .= "\n " . $self->get_Row_Rs_label($_) for ($Rs->all);
    return $str;
  }

  my $Source = $Row->result_source;
  my @keys = $Source->primary_columns;
  my $data = { $Row->get_columns };
  
  my $str = ref($Row) . ' [ ';
  $str .= $_ . ': ' . $data->{$_} . ' ' for (@keys);
  $str .= ']';
  
  return $str;
}

# Gets programatically added as a method named 'update_records' (see BUILD modifier method above)
# 
# This first runs updates on each supplied (and allowed) relation.
# It then re-runs a read_records to tell the client what the new values are.
#
sub _dbiclink_update_records {
  my $self = shift;
  my $params = shift;
  
  my $limit_columns;
  my $declared_columns = $self->param_decodeIf($self->c->req->params->{columns});
  $limit_columns = { map {$_=>1} @$declared_columns } if ($declared_columns);
  
  # -- current real/valid columns according to DataStore2:
  my %cols_indx = map {$_=>1} $self->column_name_list;
  # --
  
  my $arr = $params;
  $arr = [ $params ] if (ref($params) eq 'HASH');
  
  #my $Rs = $self->ResultSource->resultset;
  my $Rs = $self->baseResultSet;
  
  my @updated_keyvals = ();
  my %keyval_changes = ();
  
  # FIXME!!
  # There is a logic problem with update. The comparisons are done iteratively, and so when
  # update is called on one row, and then the backend logic changes another row that is
  # encountered later on in the update process, it can appear that rows were changed, when in fact they
  # were the original values, and it can change the data in an inconsistent/non-atomic way.
  # would be good to find a way to do this just like in create. What really needs to happen is
  # at least the column_data_alias remapping needs to be atomic (like create).
  # this currently only breaks in edge-cases (and where an incorrect/non-sensible set of colspecs
  # was supplied to begin with, but still needs to be FIXED). Needs to be thought about...
  # -- ^^^ --- UPDATE: I believe that I have solved this problem by now pushing rows into
  #                    a queue and then running updates at the end. Need to spend a bit more
  #                    time thinking about it though, so I am not removing the above comment yet
  
  try {
    $self->ResultSource->schema->txn_do(sub {
      foreach my $data (@$arr) {
        my $pkVal= $data->{$self->record_pk};
        defined $pkVal or die ref($self)."->update_records: Record is missing primary key '".$self->record_pk."'";
        my $BaseRow = $Rs->search($self->record_pk_cond($pkVal))->next or die usererr "Failed to find row by record_pk: $pkVal";
        
        # -- Filter out the supplied data packet according to the supplied 'columns' parameter
        # if the client has supplied a column list, filter out fieldnames that aren't in it.
        # The Ext store currently sends all of its configured store fields, including ones it never 
        # loaded from the database. If we don't do this filtering, those fields will appear to have
        # changed.
        #
        # FIXME: handle this on the client/js side so these fields aren't submitted at all
        if($limit_columns) {
          %$data = map { $_ => $data->{$_} } grep { $limit_columns->{$_} } keys %$data;
        }
        # --
        
        my @columns = grep { $_ ne $self->record_pk && $_ ne 'loadContentCnf' } keys %$data;
        
        @columns = $self->TableSpec->filter_updatable_columns(@columns);

        # -- Limit to current real/valid columns according to DataStore2:
        @columns = grep { $cols_indx{$_} } @columns;
        # --
        
        my @update_queue = $self->prepare_record_updates($BaseRow,\@columns,$data);
        
        # Update all the rows at the end:
        $self->process_update_queue(@update_queue);
    
        # Get the new record_pk for the row (it probably hasn't changed, but it could have):
        my $newPkVal = $self->generate_record_pk_value({ $BaseRow->get_columns });
        push @updated_keyvals, $newPkVal;
        $keyval_changes{$newPkVal} = $pkVal unless ("$pkVal" eq "$newPkVal");
      }
    });
  }
  catch {
    my $err = shift;
    $self->handle_dbic_exception($err);
    #die usererr rawhtml $self->make_dbic_exception_friendly($err), title => 'Database Error';
  };
  
  # --
  # Perform a fresh lookup of all the records we just updated and send them back to the client:
  delete $self->c->req->params->{ $self->_rst_qry_param } if (
    # clear any existing rst_qry to prevent polluting the read
    exists $self->c->req->params->{ $self->_rst_qry_param }
  );
  my $newdata = $self->DataStore->read({
    columns => [ keys %{ $arr->[0] } ], 
    id_in   => \@updated_keyvals
  });
  # --
  
  ## ----------------
  # NEW: We need to make sure the order of the returned rows matches the supplied rows;
  # Ext's data store uses the order rather than the record ids to match. If we don't do
  # this it could mix up the rows and cause subsequent updates to change the wrong rows!!
  {
    my %pkRowMap = map { $_->{$self->record_pk} => $_ } @{$newdata->{rows}};
    my $supplied_count = scalar @updated_keyvals;
    my $returned_count = scalar keys %pkRowMap;
    die "Supplied/returned row mismatch. Expected $supplied_count rows, got $returned_count. "
      unless ($supplied_count == $returned_count);
    
    # Manually set the correct order
    @{$newdata->{rows}} = map { $pkRowMap{$_} } @updated_keyvals;
  }
  ## ----------------
  
  
  # -- Restore the original record_pk, if it changed, and put the new value in another key.
  # This is needed to make sure the client can keep track of which row is which. Code in datastore-plus
  # then detects this and updates the idProperty in the record to the new value so it will be used
  # in subsequent requests. THIS APPLIES ONLY IF THE PRIMARY KEYS ARE EDITABLE, WHICH ONLY HAPPENS
  # IN RARE SITUATIONS:
  foreach my $row (@{$newdata->{rows}}) {
    my $newPkVal = $row->{$self->record_pk};
    my $oldPkVal = $keyval_changes{$newPkVal} or next;
    $row->{$self->record_pk . '_new'} = $row->{$self->record_pk};
    $row->{$self->record_pk} = $oldPkVal;
  }
  # --
  
  return {
    %$newdata,
    success => \1,
    msg => 'Update Succeeded'
  };
}

sub process_update_queue {
  my $self = shift;
  my @update_queue = @_;
  
  foreach my $upd (@update_queue) {
    if($upd->{change}) {
      $upd->{row}->update($upd->{change});
    }
    elsif($upd->{rel_update}) {
      # Special handling for updates to relationship columns 
      #(which aren't real columns):
      $self->apply_virtual_rel_col_update($upd->{row},$upd->{rel_update});
    }
  }
}

# currently this just handles updates to m2m relationship columns, but, this is
# also where other arbitrary update logic could go for other kinds of virtual
# columns that may be added in the future
sub apply_virtual_rel_col_update {
  my $self = shift;
  my $UpdRow = shift;
  my $update = shift;
  
  my $Source = $UpdRow->result_source;
  
  foreach my $colname (keys %$update) {
    ## currently ignore everything but m2m relationship columns:
    my $info = $Source->relationship_info($colname) or next;
    my $m2m_attrs = $info->{attrs}->{m2m_attrs} or next;
    
    # This method should have been setup by the call to "many_to_many":
    my $method = 'set_' . $colname;
    $UpdRow->can($method) or die "Row '" . ref($UpdRow) . 
      "' missing expected many_to_many method '$method' - cannot update m2m data for '$colname'!";
    
    my @ids = split(/\s*,\s*/,$update->{$colname});
    
    my $Rs = $Source->schema->source($m2m_attrs->{rrinfo}->{source})->resultset;
    my $keycol = $m2m_attrs->{rrinfo}->{cond_info}->{foreign};
    
    my @rrows = $self->_chain_search_rs($Rs,{ $keycol => { '-in' => \@ids }})->all;
    my $count = scalar @rrows;
    
    scream_color(WHITE.ON_BLUE.BOLD,"  --> Setting '$colname' m2m links (count: $count)")
      if($self->c->debug);
    
    $UpdRow->$method(\@rrows);
  }
}


# moved/generalized out of _dbiclink_update_records to also be used by batch_update:
sub prepare_record_updates {
  my $self = shift;
  my $BaseRow = shift;
  my $columns = shift;
  my $data = shift;
  my $ignore_current = shift;
  
  my @update_queue = ();
  
  $self->TableSpec->walk_columns_deep(sub {
    my $TableSpec = shift;
    my @columns = @_;
    
    my $Row = $_{return} || $BaseRow;
    return ' ' if ($Row eq ' ');
    
    my $rel = $_{rel};
    my $UpdRow = $rel ? $Row->$rel : $Row;
    
    
    # ---- New partial/preliminary auto create relationship support
    #
    # 1st-level relationships that don't already exist that are listed in the
    # 'update_create_rels' attr will be automatically created (as blank so they 
    # can be updated in the subsequent update process)
    # 
    # TODO: support any depth via an alternate 'update_create_relspec' attr and
    # create with supplied column values instead of blank (1 step instead of 2)
    #
    my %ucrls = map {$_=>1} @{$self->update_create_rels};
    if($rel && !$UpdRow && $ucrls{$rel} && $_{depth} == 1){
      $UpdRow = $Row->create_related($rel,{})->get_from_storage;
      my $msg = 'Auto CREATED RELATED -> ' . $self->get_Row_Rs_label($UpdRow) . "\n";
      scream_color(WHITE.ON_GREEN.BOLD,$msg) if($self->c->debug);
    }
    #
    # ----
    
    
    my %update = map { $_ => $data->{ $_{name_map}->{$_} } } keys %{$_{name_map}};
    
    # --- Need to do a map and a grep here; map to remap the values, and grep to prevent
    # the new values from being clobbered by identical key names from the original data:
    my $alias = { %{ $TableSpec->column_data_alias } };
    # -- strip out aliases that are identical to the original value. This will happen in the special
    # case of an update to a rel col that is ALSO a local col when 'priority_rel_columns' is on.
    # It shouldn't happen other times, but if it does, this is the right way to handle it, regardless:
    $_ eq $alias->{$_} and delete $alias->{$_} for (keys %$alias);
    # --
    my %revalias = map {$_=>1} values %$alias;
    %update = map { $alias->{$_} ? $alias->{$_} : $_ => $update{$_} } grep { !$revalias{$_} } keys %update;
    # ---
    
    unless (defined $UpdRow) {
      scream('NOTICE: Relationship/row "' . $rel . '" is not defined',\@columns)
        if($self->c->debug);
      
      # New: Throw an error when trying to update a column through a missing relationship so
      # the user knows instead of silenting ignoring those columns.
      # TODO: make this an option and alternatively *create* the missing relationship based on
      # settings of the relationship (needs an API/design to be thought up)
      if($rel) {
        my $relf = '<span style="font-weight:bold;color:navy;">' . $rel . '</span>';
        my $cols = '<span style="font-family:monospace;font-size:.85em;">' . join(', ',keys %update) . '</span>';
        my $html = '<span style="font-size:1.3em;">' .
          "Cannot update related field(s) of $relf ($cols) because there is no $relf set for this record. " .
          "<br><br>This probably just means you need to add or select a $relf first.</span>";
        die usererr rawhtml $html, title => "Can't update fields of non-existant related '$rel' ";
      }
    }
    
    # This should throw an error to the user, too:
    if ($UpdRow->isa('DBIx::Class::ResultSet')) {
      scream('NOTICE: Skipping multi relationship "' . $rel . '"')
        if($self->c->debug); 
      return ' ';
    }

    
    # --- pull out updates to virtual relationship columns
    my $Source = $UpdRow->result_source;
    my $relcol_updates = {};
    (!$Source->has_column($_) && $Source->has_relationship($_)) and
      $relcol_updates->{$_} = delete $update{$_} for (keys %update);
    # add to the update queue with a special attr 'rel_update' instead of 'change'
    push @update_queue,{ row => $UpdRow, rel_update => $relcol_updates } 
      if (keys %$relcol_updates > 0);
    # ---
    
    my $change = \%update;
    
    unless($ignore_current) {
    
      my %current = $UpdRow->get_columns;
      
      $change = {};
      foreach my $col (keys %update) {
        no warnings 'uninitialized';
        next unless (exists $current{$col});
        next if (! defined $update{$col} and ! defined $current{$col});
        next if ($update{$col} eq $current{$col});
        $change->{$col} = $update{$col};
      }
      
      my $msg = 'Will UPDATE -> ' . $self->get_Row_Rs_label($UpdRow) . "\n";
      if (keys %$change > 0){ 
        my $t = Text::TabularDisplay->new(qw(column old new));
        $t->add($_,print_trunc(60,$current{$_}),print_trunc(60,$change->{$_})) for (keys %$change);
        $msg .= $t->render;
      }
      else {
        $msg .= 'No Changes';
      }
      scream_color(WHITE.ON_BLUE.BOLD,$msg) if($self->c->debug);
    }
    
    push @update_queue,{ row => $UpdRow, change => $change };

    return $UpdRow;
  },@$columns);
  
  return @update_queue;
}

# Works with the hashtree supplied to create_records to recursively 
# remap columns according to supplied TableSpec column_data_aliases
sub hashtree_col_alias_map_deep {
  my $self = shift;
  my $hash = shift;
  my $TableSpec = shift;
  
  # Recursive:
  foreach my $rel (grep { ref($hash->{$_}) eq 'HASH' } keys %$hash) {
    my $rel_TableSpec = $TableSpec->related_TableSpec->{$rel} or next;
    $hash->{$rel} = $self->hashtree_col_alias_map_deep($hash->{$rel},$rel_TableSpec);
  }
  
  # -- Need to do a map and a grep here; map to remap the values, and grep to prevent
  # the new values from being clobbered by identical key names from the original data:
  my $alias = $TableSpec->column_data_alias;
  my %revalias = map {$_=>1} grep {!exists $hash->{$_}} values %$alias;
  %$hash = map { $alias->{$_} ? $alias->{$_} : $_ => $hash->{$_} } grep { !$revalias{$_} } keys %$hash;
  # --
  
  # --- remap special m2m relationship column values:
  # see apply_virtual_rel_col_update() above for the 'update' version
  my $Source = $TableSpec->ResultSource;
  foreach my $col (keys %$hash) {
    next if ($Source->has_column($col));
    my $info = $Source->relationship_info($col) or next;
    my $m2m_attrs = $info->{attrs}->{m2m_attrs} or next;
    my $keycol = $m2m_attrs->{rrinfo}->{cond_info}->{foreign};
    
    my @ids = split(/\s*,\s*/,$hash->{$col});
    
    # Convert the value into a valid "has_many" create packet:
    $hash->{$col} = [ map { { $keycol => $_ } } @ids ]; 
  }
  # ---
  
  return $hash;
}


# Gets programatically added as a method named 'create_records' (see BUILD modifier method above)
sub _dbiclink_create_records {
  my $self = shift;
  my $params = shift;
  
  my $arr = $params;
  $arr = [ $params ] if (ref($params) eq 'HASH');
  
  #my $Rs = $self->ResultSource->resultset;
  my $Rs = $self->baseResultSet;
  
  # create_columns turned off in 080-DataStore.js - 2014-11-24 by HV
  #my @req_columns = $self->get_req_columns(undef,'create_columns');
  my @req_columns = $self->get_req_columns;
  
  # -- current real/valid columns according to DataStore2:
  my %cols_indx = map {$_=>1} $self->column_name_list;
  # --
  
  my @updated_keyvals = ();

  try {
    $self->ResultSource->schema->txn_do(sub {
      foreach my $data (@$arr) {

        # Apply optional base/hard coded data:
        %$data = ( %$data, %{$self->_CreateData} );
        my @columns = uniq(keys %$data,@req_columns);
        @columns = grep { $_ ne $self->record_pk && $_ ne 'loadContentCnf' } @columns;
        @columns = $self->TableSpec->filter_creatable_columns(@columns);
        
        # -- Limit to current real/valid columns according to DataStore2:
        @columns = grep { $cols_indx{$_} } @columns;
        # --
        
        my $relspecs = $self->TableSpec->columns_to_relspec_map(@columns);
      
        my $create_hash = {};
        
        foreach my $rel (keys %$relspecs) {
          $create_hash->{$rel} = {} unless (defined $create_hash->{$rel}); 
          exists $data->{$_->{orig_colname}} and $create_hash->{$rel}->{$_->{local_colname}} = $data->{$_->{orig_colname}} 
            for (@{$relspecs->{$rel}});
        }
        
        my $create = delete $create_hash->{''} || {};
        $create = { %$create_hash, %$create };
        
        # -- Recursively remap column_data_alias:
        $create = $self->hashtree_col_alias_map_deep($create,$self->TableSpec);
        # --
        
        my $msg = 'CREATE -> ' . ref($Rs) . "\n";
        if (keys %$create > 0){ 
          my $t = Text::TabularDisplay->new(qw(column value));
          #$t->add($_,ref $create->{$_} ? Dumper($create->{$_}) : $create->{$_} ) for (keys %$create);
          #$t->add($_,disp(sub{ ref $_ ? Dumper($_) : undef },$create->{$_}) ) for (keys %$create);
          $t->add($_,print_trunc(60,$create->{$_})) for (keys %$create);
          $msg .= $t->render;
        }
        else {
          $msg .= 'Empty Record';
        }
        scream_color(WHITE.ON_GREEN.BOLD,$msg) if($self->c->debug);
        my $Row = $Rs->create($create);
        
        push @updated_keyvals, $self->generate_record_pk_value({ $Row->get_columns });
      }
    });
  }
  catch {
    my $err = shift;
    $self->handle_dbic_exception($err);
    #die usererr rawhtml $self->make_dbic_exception_friendly($err), title => 'Database Error';
  };
  
  # --
  # Perform a fresh lookup of all the records we just updated and send them back to the client:
  delete $self->c->req->params->{ $self->_rst_qry_param } if (
    # clear any existing rst_qry to prevent polluting the read
    exists $self->c->req->params->{ $self->_rst_qry_param }
  );
  my $newdata = $self->DataStore->read({
    columns => \@req_columns, 
    id_in   => \@updated_keyvals
  });
  # --
  
  die usererr rawhtml "Unknown error; no records were created", 
    title => 'Create Failed' unless ($newdata && $newdata->{results});
  
  return {
    %$newdata,
    success => \1,
    msg => 'Create Succeeded',
    use_this => 1
  };
}

# Gets programatically added as a method named 'destroy_records' (see BUILD modifier method above)
sub _dbiclink_destroy_records {
  my $self = shift;
  my $params = shift;
  
  my $arr = $params;
  $arr = [ $params ] if (not ref($params));
  
  #my $Rs = $self->ResultSource->resultset;
  my $Rs = $self->baseResultSet;
  
  try {
    $self->ResultSource->schema->txn_do(sub {
      my @Rows = ();
      foreach my $pk (@$arr) {
        my $Row = $Rs->search($self->record_pk_cond($pk))->next or die usererr "Failed to find row by record_pd: $pk";
        
        foreach my $rel (reverse sort @{$self->destroyable_relspec}) {
          next unless(
            $rel =~ /^[a-zA-Z0-9\-\_]+$/ 
            and $Row->can($rel)
          );
          
          my $relObj = $Row->$rel;
          
          scream_color(WHITE.ON_RED.BOLD,'DbicLink2 DESTROY --> ' . ref($Row) . '->' . $rel . ' --> ' .$self->get_Row_Rs_label($relObj,1) . "\n") if($self->c->debug);
          $relObj->can('delete_all') ? $relObj->delete_all : $relObj->delete;
        }
        scream_color(WHITE.ON_RED.BOLD,'DbicLink2 DESTROY --> ' . $self->get_Row_Rs_label($Row,1) . "\n")
          if($self->c->debug);
        $Row->delete;
      }
    });
  }
  catch {
    my $err = shift;
    $self->handle_dbic_exception($err);
    #die usererr rawhtml $self->make_dbic_exception_friendly($err), title => 'Database Error';
  };
  
  return 1;
}



sub extract_db_error_from_exception {  
  my $self = shift;
  my $exception = shift;
  die $exception if (ref($exception) =~ /^RapidApp\:\:Responder/);
  
  warn $exception;
  
  my $msg = "" . $exception . "";
  
  my @parts = split(/DBD\:\:.+\:\:st execute failed\:\s*/,$msg);
  return undef unless (scalar @parts > 1);
  
  $msg = $parts[1];
  @parts = split(/\s*\[/,$msg);
  
  return $parts[0];
}


sub handle_dbic_exception {
  my $self = shift;
  my $exception = shift;
  
  my $msg = $self->extract_db_error_from_exception($exception);
  $msg = $msg ? "$msg\n\n----------------\n" : '';

  my $html = '<pre>' . $msg . $exception . "</pre>";
  
  die usererr rawhtml $html, title => "Database Error $append_exception_title";
  
  #die $exception if (ref($exception) =~ /^RapidApp\:\:Responder/);
  #die usererr rawhtml $self->make_dbic_exception_friendly($exception), title => 'DbicLink2 Database Error';
}


sub make_dbic_exception_friendly {
  my $self = shift;
  my $exception = shift;
  
  warn $exception;
  
  my $msg = "" . $exception . "";
  
  
  #### Fix me!!!! ####
  # Randomly getting this DBIx exception when throwing a customprompt object within CRUD operations
  # no idea silently pass it up for now
  die infostatus msg => "Bizarre copy of HASH in aassign", status => 500 if ($msg =~/Bizarre copy of HASH in aassign/);
  
  
  
  my @parts = split(/DBD\:\:mysql\:\:st execute failed\:\s*/,$msg);
  return $exception unless (scalar @parts > 1);
  
  $msg = $parts[1];
  
  @parts = split(/\s*\[/,$msg);

  return '<center><pre>' . $parts[0] . "</pre></center>";
  return $parts[0];
}


sub param_decodeIf {
  my $self = shift;
  my $param = shift;
  my $default = shift || undef;
  
  return $default unless (defined $param);
  
  return $param if (ref $param);
  my $decoded;
  try {
    $decoded = $self->json->decode($param);
  }
  catch {
    my $err = shift;
    confess "$err \n\nINPUT STRING: '$param'\n\n";
  };
  return $decoded;
}


# This is a DbicLink2-specific implementation of batch_update. Overrides generic method 
# in DataStore2. It is able to perform much better with large batches
sub batch_update {
  my $self = shift;
  
  # See DataStore2:
  $self->before_batch_update;
  
  my $editSpec = $self->param_decodeIf($self->c->req->params->{editSpec});
  my $read_params = $editSpec->{read_params};
  my $update = $editSpec->{update};
  
  delete $read_params->{start};
  delete $read_params->{limit};
  
  my %orig_params = %{$self->c->req->params};
  %{$self->c->req->params} = %$read_params;
  my $Rs = $self->get_read_records_Rs($read_params);
  %{$self->c->req->params} = %orig_params;
  
  # Remove select/as so the columns are normal (these select/as attrs only apply to read_records)
  delete $Rs->{attrs}->{select};
  delete $Rs->{attrs}->{as};
  
  my $total = $Rs->pager->total_entries;
  
  die usererr "Update count mismatch (" . 
    $editSpec->{count} . ' vs ' . $total . ') ' .
    "- This can happen if someone else modified one or more of the records in the update set.\n\n" .
    "Reload the the grid and try again."
  unless ($editSpec->{count} == $total);
  
  my @columns = grep { $_ ne $self->record_pk && $_ ne 'loadContentCnf' } keys %$update;
  @columns = $self->TableSpec->filter_updatable_columns(@columns);
  
  try {
    $self->ResultSource->schema->txn_do(sub {
    
      my $ignore_current = 1;
      my @update_queue = ();
      push(@update_queue, $self->prepare_record_updates($_,\@columns,$update,$ignore_current)) 
        for ($Rs->all);
      
      # Update all the rows at the end:
      $self->process_update_queue(@update_queue);
    });
  }
  catch {
    my $err = shift;
    $self->handle_dbic_exception($err);
  };
  
  return 1;
}


1;