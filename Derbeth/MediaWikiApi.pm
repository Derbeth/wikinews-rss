package Derbeth::MediaWikiApi;
use strict;
use utf8;

use Derbeth::Web;

use URI::Escape;
use YAML::Any;

sub rendered_page {
	my ($wiki_base, $page_title) = @_;
	my $query_url = $wiki_base."/w/api.php?action=parse&format=yaml&prop=text|revid&disablepp=true&page=".uri_escape_utf8($page_title);
	my $parse_response = Derbeth::Web::get_page($query_url);
	unless($parse_response) {
		return undef;
	}
	my $parsed = Load($parse_response);
	my $page_text = $parsed->{parse}->{text}->{'*'};
	unless($page_text && $parsed->{parse}->{revid}) {
		return undef;
	}
	return $page_text;
}

1;
