package RapidApp::AttributeHandlers;
use RapidApp::Include qw(sugar perlutil);

unshift @UNIVERSAL::ISA, __PACKAGE__;

use Attribute::Handlers;
use strict;

#     Note: These handlers are ignored in DBIC classes with:
#
# use base 'DBIx::Class';
#
#     but do work with:
#
# require base; base->import('DBIx::Class');
#
#     and do work with:
#
# use Moose;
# use MooseX::NonMoose;
# use namespace::autoclean;
# extends 'DBIx::Class'; MooseX::NonMoose
#
#     This is probably a bug in DBIC.
#
# See my IRC chat in #dbix-class on 2011-11-05:
=pod
[15:44] <vs> Attribute::Handlers with DBIC Component classes, is there a trick to get it to work properly? I want to be able to have custom attributes defined in a separate package, and then include it it with use base, or load_componenets, or anything that will actually work, and have those attributes available for setting on the subs in the DBIC class... Sub::Attribute works, but has less features than Attribute::Handlers... is there a reason it doesn't work with Attribute::Hanlders?
[15:45] <alnewkirk> vs, ... wtf?
[15:45] <vs> heh
[15:46] <alnewkirk> vs, DBIC already does this without any extra modules needed
[15:48] <vs> ok.... how/where?
[15:49] <vs> to clearify, I'm not talking about class accessors... I am talking about being able to define sub mysub :MyAttr { ... } and then be able to hook into the 'MyAttr' attribute
[15:50] <alnewkirk> vs, why?
[15:51] <vs> I'd like to use it for debug/introspection... but I really just want to be able t use it for any purposes that one would use attributes in any other regulat packages...
[15:51] <vs> just wanting to understand why it seems to be different for DBIC..
[15:52] <vs> is it related to class:c3  stuff?
[16:04] <vs> Because it does work with MooseX::NonMoose/extends 'DBIx::Class', but does not work with use base 'DBIx::Class' ... I don't want to have to load Moose on my DBIC classes if I don't have to because of the extra overhead
[16:05] * siracusa (~siracusa@pool-96-233-50-4.bstnma.fios.verizon.net) has joined #dbix-class
[16:32] <@Caelum> vs: you need to put the ->load_components call into a BEGIN {} block
[16:32] <@Caelum> ner0x: the difference between has_one and belongs_to, is that belongs_to defines a foreign key on deploy
[16:32] <@Caelum> ner0x: so if you want a foreign key, use belongs_to
[16:32] <vs> Caelum: I did that
[16:33] <@Caelum> vs: still didn't work?
[16:33] <purl> Maybe you should change the code!  Or your definition of "works". or like not good or nun violence never pays
[16:33] <vs> I tried that, and use base qw(MyAttrClass DBIx::Class) and neither work
[16:34] <vs> it does work with Sub::Attribute
[16:35] <vs> It doesn't throw errors about invalid CODE attributes, but the handle code never gets called...
[16:35] <@Caelum> so if you load your base class at runtime, it works, but at compile time it doesn't
[16:36] <vs> I can only get it to work if I put the atttribute definitions in the package directly
[16:36] <@Caelum> try: require base; base->import('DBIx::Class');
[16:36] <@Caelum> that would be the equivalent of the Moose "extends"
[16:37] <vs> aha... ok, let me try that... 
[16:38] <vs> yep, that works!
[16:38] <@Caelum> bonus points if you can figure out why and submit the appropriate RT tickets :)
[16:39] <vs> I've been beating my head against this for hours... it reminds me how much I still don't know about perl...
[16:41] <vs> but if I can figure it out, I'll send the feedback!
[16:41] <@Caelum> I think there was a MODIFY_CODE_ATTRIBUTES method in DBIx/Class.pm
[16:41] <@Caelum> I don't know why it's there
[16:42] <vs> yep, I know there is... because during some of my tests i saw messsages about it being redefined
[16:42] <vs> redefined by DBIx::Class....
[16:42] <vs> I figured it had to be related to the c3 stuff
[16:43] <@Caelum> it isn't
[16:43] <@Caelum> ask ribasushi he probably knows
=cut

sub Debug :ATTR(CODE,BEGIN) {
	my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
	
	my $name = *{$symbol}{NAME};
	
	die __PACKAGE__ . '::Debug(): invalid attribute data: "' . $data . '" - expected hash/list arguments' 
		if (defined $data and ref($data) ne 'ARRAY');
	
	scream_color(BOLD.CYAN,"debug_around set on: $package" . '::' . "$name at line $linenum");
	
	my %opt = (pkg => $package, filename => $filename, line => $linenum);
	%opt = ( %opt, @$data ) if (ref($data) eq 'ARRAY');

	return debug_around($name,%opt);
}

sub nDebug :ATTR(CODE,BEGIN) {
	my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
	
	my $name = *{$symbol}{NAME};
	
	scream_color(BOLD.CYAN,"NOT setting debug_around on: $package" . '::' . "$name at line $linenum");
}

=pod
use Sub::Attribute;

# Automatically setup 'debug_around' on methods with the 'Debug' attribute:
sub Debug :ATTR_SUB {
	my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
	
	scream(join('',
		ref($referent), " ",
		*{$symbol}{NAME}, " ",
		"($referent) ", "was just declared ",
		"and ascribed the ${attr} attribute ",
		"with data ($data)\n",
		"in phase $phase\n",
		"in file $filename at line $linenum\n"
	));
	
	
	return debug_around(*{$symbol}{NAME}, pkg => $package, filename => $filename, line => $linenum);
}


=cut

1;