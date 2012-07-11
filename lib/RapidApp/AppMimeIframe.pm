package RapidApp::AppMimeIframe;
use strict;
use warnings;
use Moose;
extends 'RapidApp::AppCmp';

use RapidApp::Include qw(sugar perlutil);

has 'get_id_code', is => 'ro', lazy => 1, isa => 'CodeRef', default => sub { die "Virtual Method!" };
has 'get_content_code', is => 'ro', lazy => 1, isa => 'CodeRef', default => sub { die "Virtual Method!" };
has 'title', is => 'ro', isa => 'Str', default => 'Mime Content';

sub get_id { my $self = shift; return $self->get_id_code->($self,@_); }
sub get_content { my $self = shift; return $self->get_content_code->($self,@_); }

sub BUILD {
	my $self = shift;
	
	$self->apply_extconfig(
		xtype => 'iframepanel',
		title => $self->title,
		iconCls => 'icon-email',
		collapsible => \1,
		titleCollapse => \1,
		style => 'height: 100%;',
		bodyStyle => 'border: 1px solid #D0D0D0;background-color:white;',
		loadMask => \1,
		height => 400 #<-- initial height, should be adjusted by 'iframe-autoheight' below
	);
	
	$self->add_plugin( 'titlecollapseplus' );
	$self->add_plugin( 'iframe-autoheight' );
	
	$self->apply_actions( mime_content => 'mime_content' );
}



before content => sub {
	my $self = shift;
	
	my $id = $self->get_id or return undef;
	$self->apply_extconfig( defaultSrc => $self->suburl('mime_content') . '?id=' . $id );
};


sub mime_content {
	my $self = shift;
	my $params = $self->c->req->params;

	my $content = $self->get_content or return '<h1><center>Content Not Found</center></h1>';
	
	my $Message = Email::MIME->new($content);
	
	return $self->render_cid($Message,$params->{cid}) if($params->{cid});
	
	my @parts = $Message->parts;
	
	return $content unless (defined $parts[1]);
	
	my $Rich = ($parts[1]->parts)[0];
	
	my $p = '<p style="margin-top:3px;margin-bottom:3px;">';
	
	my $html = '';
	
	$html .= '<div style="font-size:90%;">';
	#$html .= $p . '<b>' . $_ . ':&nbsp;</b>' . join(',',$Rich->header($_)) . '</p>' for ($Rich->header_names);
	$html .= $p . '<b>' . $_ . ':&nbsp;</b>' . join(',',$Message->header($_)) . '</p>' for (qw(From Date To Subject));
	$html .= '</div>';
	
	$html .= '<hr><div style="padding-top:15px;"></div>';
	
	$html .= $Rich->body_str;
	
	$self->convert_cids(\$html);
	
	return $html;
}


sub render_cid {
	my $self = shift;
	my $Message = shift || return;
	my $cid = shift || return;
	
	my $FoundPart;
	
	$Message->walk_parts(sub {
		my $Part = shift;
		return if ($FoundPart);
		$FoundPart = $Part if ( $Part->header('Content-ID') and (
			$cid eq $Part->header('Content-ID') or 
			'<' . $cid . '>' eq $Part->header('Content-ID')
		));
	});
	
	unless ($FoundPart) {
		$self->c->scream('Content-ID ' . $cid . ' not found.');
		die 'Not found.';
	}
	
	foreach my $header ($FoundPart->header_names) {
		next if($header eq 'Date'); #<-- if Date gets set it kills the session cookie
		$self->c->res->header( $header => $FoundPart->header($header) );
	}
	
	return $FoundPart->body;

}

sub convert_cids {
	my $self = shift;	
	my $htmlref = shift;

	my $parser = HTML::TokeParser::Simple->new($htmlref);
	
	my $substitutions = {};
	
	while (my $tag = $parser->get_tag) {
	
		my $attr;
		if($tag->is_tag('img')) {
			$attr = 'src';
		}
		elsif($tag->is_tag('a')) {
			$attr = 'href';
		}
		else {
			next;
		}
		
		my $url = $tag->get_attr($attr) or next;
		next unless ($url =~ /^cid\:/);
		
		my $newurl = $self->cid_to_real_url($url);
		if ($newurl) {
			my $find = $tag->as_is;
			$tag->set_attr($attr,$newurl);
			$substitutions->{$find} = $tag->as_is;
		}
	}
	
	foreach my $find (keys %$substitutions) {
		my $replace = $substitutions->{$find};
		$$htmlref =~ s/\Q$find\E/$replace/gm;
	}
}

sub cid_to_real_url {
	my $self = shift;
	my $url = shift;
	
	my ($junk,$cid) = split(/\:/,$url);
	
	return $self->suburl('mime_content') . '?cid=' . $cid . '&id=' . $self->c->req->params->{id};
}


1;
