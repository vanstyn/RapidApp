package RapidApp::DirectLink::LinkFactory;

use strict;
use warnings;
use Moose;

use DateTime;
use RapidApp::DirectLink::Link;
use Scalar::Util 'blessed';
use Data::Dumper;
use Try::Tiny;

=head1 NAME

RapidApp::DirectLink::LinkFactory

=head1 SYNOPSIS

  CREATE TABLE direct_link (
    create_date DATE NOT NULL,
    random_hash char(8) NOT NULL,
    params varchar(255) NOT NULL,
  );
  
  ...
  
  my $directLinks= RapidApp::DirectLink::LinkFactory(schema => $self->c->model("DB"));
  
  my $directLinks= RapidApp::DirectLink::LinkFactory(schema => $self->c->model("DB"), directLinkSourceName => 'MyDirectLink');
  
  # careful, this one binds the LinkFactory to a catalyst instance
  my $directLinks= RapidApp::DirectLink::LinkFactory(directLinkRS => sub { $self->c->model("DB::DirectLink") });
  
  my $link= $directLinks->create(auth => { user => $contact_id, acl => { etc } }, targetUrl => 'foo/bar');
  
  my $link= $directLinks->load(linkUid => $self->c->request->params->{id});

=head1 DESCRIPTION

This class provides methods for creating, retrieving, and cleaning DirectLinks.

It requires a ResultSource with the following definition:
   create_date DATE NOT NULL,
   random_hash char(8) NOT NULL,
   params varchar(255) NOT NULL,

By default, it looks for a ResultSource named 'DirectLink', though this is configurable.

=cut

has 'schema' => ( is => 'rw', isa => 'DBIx::Class::Schema' );
has 'directLinkSourceName' => ( is => 'rw', isa => 'Str', default => 'DirectLink' );
has 'directLinkRS' => ( is => 'rw' ); # is either a ResultSource, or a coderef that returns one

=head1 ATTRIBUTES

=over

=item schema

Some object which can "->source($name)".  Will usually be a DBIx::Class::Schema.

=item directLinkSourceName

The name of the result source to use, if using the 'schema' attribute.

=item directLinkRS

Either an instance of DBIx::Class::ResultSource, or a coderef which returns one when evaluated with no arguments.

If directLinkRS is given, schema and directLinkSourceName will be ignored.

=head1 METHODS

=cut

sub _getDirectLinkSource {
	my $self= shift;
	return $self->directLinkRS->() if ref $self->directLinkRS eq 'CODE';
	return $self->directLinkRS if ref $self->directLinkRS ne '';
	
	my $rsName= $self->directLinkSourceName;
	return $self->schema->source($rsName) if defined $self->schema;
	
	die 'Result Source for DirectLinks has not been configured';
}

=head2 createLink

Create a new DirectLink from supplied parameters.  Most of the parameters will become part of a
hash which gets serialized into a JSON string, so make sure they are serializable.

This function takes care of ensuring that the current date and a unique hash are chosen.

The parameters may be anything that is valid for the constructor of DirectLink::Link.

=cut

sub genRandChar {
	# the rand function follows a pattern, so we're not getting the full entropy we could get from these 8 bytes.
	# XXX replace with a better random source if we find a convenient and efficient module for it.
	my $x= int(rand(62));
	return chr(ord('0')+$x) if ($x < 10);
	return chr(ord('A')-10+$x) if ($x < 36);
	return chr(ord('a')-36+$x);
}
sub genRandHash {
	my $str= '';
	for (my $i=0; $i < 8; $i++) {
		$str.= &genRandChar;
	}
	return $str;
}

sub createLink {
	my $self= shift;
	
	my $link= (blessed($_[0]) && $_[0]->isa('RapidApp::DirectLink::Link'))? $_[0] : RapidApp::DirectLink::Link->new(@_);
	
	$link->has_creationDate or $link->creationDate(DateTime->now);
	
	my $rs= $self->_getDirectLinkSource();
	my $attempt= 0;
	my $result= undef;
	while (!defined $result && $attempt < 5) {
		try {
			$link->randomHash($self->genRandHash) if !$link->has_randomHash;
			
			$rs->resultset->create({
				create_date => $link->creationDate,
				random_hash => $link->randomHash,
				params => $link->paramsJson,
			});
			$result= $link;
		}
		catch {
			my $err= $_;
			# else, if the record failed to insert because of a duplicate key, try again with a new hash
			my $found= $rs->resultset->search({ create_date => $link->creationDate, random_hash => $link->randomHash })->count;
			die $err unless $found > 0;
			
			# the hash existed... try a different one
			$link->clear_randomHash();
			$attempt++;
		};
	}
	defined $result or die "Failed $attempt attempts to create a unique link ID";
	return $result;
}

=head2 loadByUid

Load a link from the database via its unique ID.  This is used when the user follows a hyperlink
to the DirectLink::Redirector controller.

=cut

sub loadByUid {
	my ($self, $uid)= @_;
	
	my $rs= $self->_getDirectLinkSource();
	my $date= RapidApp::DirectLink::Link->dateFromLinkUid($uid);
	my $hash= RapidApp::DirectLink::Link->hashFromLinkUid($uid);
	my $rec= $rs->resultset->find({ create_date => $date, random_hash => $hash });
	
	return RapidApp::DirectLink::Link->new(creationDate => $date, randomHash => $hash, params => $rec->params);
}

sub deleteLink {
	die 'Unimplemented';
}

sub expireOldLinks {
	die 'Unimplemented';
}

=head1 SEE ALSO

RapidApp::DirectLink::LinkFactory

RapidApp::DirectLink::Link

RapidApp::DirectLink::SessionLoader

=cut

1;