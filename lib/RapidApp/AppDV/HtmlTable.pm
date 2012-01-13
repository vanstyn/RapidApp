package RapidApp::AppDV::HtmlTable;
use warnings;
use Moose;
extends 'RapidApp::AppDV';

use RapidApp::Include qw(sugar perlutil);

=head1 NAME

RapidApp::AppDV::HtmlTable - Table generator for RapidApp/AppDV 

=head1 DESCRIPTION

This module generates a nicely laid out "Property" (name/value pairs) HTML
table according to the data structure in 'tt_table_data' which should look 
like this:

  [
   [
     { name => "Some Label/Heading", value => "Some value" },
     { name => "foo", value => "BLAH" },
     { name => "abc", value => "xyc" },
   ],
   [
     { name => "Some Label, top of second column group", value => "Some value" },
     { name => "aaa", value => "123" }
   ]
  ]

The data should be an array of arrays, each sequential sub array defines a 
column set and contains name/value pairs

While you can manually define tt_table_data, if you don't it will be automatically
populated according to the configured DataStore2 columns.

By default 2 even column sets will be setup, but you can define 'column_layout' which
is an intermediary for generating tt_table_data like this:

  has '+column_layout', => default => sub {[
    [ 'column_name1', 'col_foo', 'another_column' ],
    [ 'col_a', 'col_b' ],
    [ 'col_z', 'col_y', 'col_x', 'col_w' ]
  ]};

The above would define 3 column groups. The headers and AppDV 'autofield' values are
populated automatically according to the DataStore2/TableSpec column configs

You can also apply extra css styles like this:

  has '+tt_css_styles', default => sub {{
    'table.property-table table.column td.name' => {
      'text-align' => 'right'
    }
  }};

The above would cause the labels to the right-justified instead of left-justified. This
is based on the css and class names that are used when the table is generated. See the
tt file (rapidapp/misc/property_table.tt) for direction on what css styles to apply

You can also override the method 'get_tt_column_data' for fine-grained control when
tt_table_data is being automatically generated from DataStore2 columns

=head1 AUTHOR

Henry Van Styn <vanstyn@intellitree.com>

=cut


has '+tt_file' => ( default => 'rapidapp/misc/property_table.tt' );

has '+extra_tt_vars' => ( default => sub {
	my $self = shift;
	return { self => $self };
});

has 'column_layout', is => 'ro', lazy => 1, isa => 'ArrayRef[ArrayRef[Str]]', traits => ['RapidApp::Role::PerRequestBuildDefReset'],
default => sub {
	my $self = shift;
	
	# Default - evenly divide fields among 2 key/val column sets:
	
	# This is duplicated in tt_table_data below because we want the columns to be balanced
	# but don't want the logic to be bypassed if column_layout is defined in the consuming class
	my @col2 = grep { $self->is_valid_colname($_) } @{$self->column_order};
	
	my @col1 = splice(@col2,0,int(scalar(@col2)/2));
	
	return [ \@col1, \@col2 ];
};


has 'tt_table_data', is => 'ro', lazy => 1, isa => 'ArrayRef[ArrayRef[HashRef[Str]]]', traits => ['RapidApp::Role::PerRequestBuildDefReset'],
default => sub {
	my $self = shift;
	
	my $arr = [];
	
	foreach my $col_set (@{$self->column_layout}) {
		my $set = [];

		$self->is_valid_colname($_) and 
			push @$set, $self->get_tt_column_data($_) for (@$col_set);
		
		push @$arr, $set;
	}
	
	return $arr;
};

sub get_tt_column_data {
	my $self = shift;
	my $col = shift;
	
	return {
		col	=> $col,
		name	=> $self->columns->{$col}->{header} || $col,
		value	=> $self->TTController->autofield->$col
	};
}


# Get's put in <style> tags, see the tt template file
has 'tt_css_styles', is => 'ro', lazy => 1, traits => ['RapidApp::Role::PerRequestBuildDefReset'],
isa => 'HashRef', default => sub {{}};

has 'tt_css_styles_str', is => 'ro', lazy => 1, isa => 'Str', traits => ['RapidApp::Role::PerRequestBuildDefReset'],
default => sub {
	my $self = shift;
	
	my $str = '';
	
	foreach my $cls (keys %{$self->tt_css_styles}) {
		$str .= "\n" . $cls . ' { ';
		
		my $styles = $self->tt_css_styles->{$cls};
		foreach my $prop (keys %$styles) {
			my $val = $styles->{$prop};
			$val =~ s/\;$//;
			$str .= "\n\t" . $prop . ': ' . $val . ';';
		}
		
		$str .= "\n" . '}' . "\n";
	
	}
	
	return $str;
};

sub is_valid_colname {
	my $self = shift;
	my $col = shift;
	
	return 1 unless (
		not defined $self->columns->{$col} or
		jstrue($self->columns->{$col}->{no_column}) or
		(
			defined $self->columns->{$col}->{allow_view} and 
			not jstrue($self->columns->{$col}->{allow_view})
		)
	);
	
	return 0;
}

sub BUILD {
	my $self = shift;

	$self->apply_extconfig(
		#xtype			=> 'dataview',
		autoHeight		=> \1,
		multiSelect		=> \1,
		simpleSelect	=> \1,
		itemSelector	=> 'div.row',
		selectedClass	=> 'x-grid3-row-checked',
		emptyText		=> $self->emptyHTML,
		itemId			=> 'dataview',
		
	);
	
}





has 'emptyHTML' => ( is => 'ro', lazy => 1, default => sub {
	my $self = shift;

	return join('',
		'<div style="border:1px solid;border-color:#d0d0d0;">',
			
			'<table class="GSprop" width="100%" height="100%" >',
				'<tbody class="GSprop">',
				
						'<tr class="GSprop">',
							
							'<td class="GSprop" style="white-space:nowrap;color:slategray;">',
								'<div style="padding-left:10px;">',
									'<span style="color:darkgrey;">(No Data)</span>',
								'</div>',
							'</td>',
							
						'</tr>',
						

				'</tbody>',
			'</table>',
		'</div>',
	);

});



1;
