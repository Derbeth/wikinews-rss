package Derbeth::MediaWikiApi;
use strict;
use utf8;

use Derbeth::Web;

use Encode;
use URI::Escape;
use YAML::Any;

if (YAML::Any->implementation eq 'YAML::Syck') {
	$YAML::Any::ImplicitUnicode = 1;
}

sub rendered_page {
	my ($wiki_base, $page_title) = @_;
	my $parsed = query($wiki_base, "/w/api.php?action=parse&format=json&prop=text|revid&disablepp=true&page=".uri_escape_utf8($page_title));
	unless(defined $parsed) {
		return undef;
	}
	if ($parsed->{error}) {
		print encode_utf8("API responded with error for '$page_title': "), $parsed->{error}->{info}, "\n";
		return undef;
	}
	my $page_text = $parsed->{parse}->{text}->{'*'};
	unless($page_text && $parsed->{parse}->{revid}) {
		return undef;
	}
	return $page_text;
}

sub query {
	my ($wiki_base, $query) = @_;
	my $query_url = $wiki_base.$query;
	my $api_response = Derbeth::Web::get_page($query_url);
	unless($api_response) {
		return undef;
	}
	return Load($api_response);
}

sub parse_yaml {
	my ($text) = @_;
	return Load($text);
}

1;
