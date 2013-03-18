package RSS::CategoryReader;
use strict;
use utf8;

use parent 'RSS::NewsListReader';

use Derbeth::MediaWikiApi;
use URI::Escape;
use Unicode::Escape;
use Encode;

sub new {
	my ($class, $wiki_base, $source, $max_new_news) = @_;
	my $self = $class->SUPER::new();
	$self->{source} = $source;
	$source = uri_escape_utf8("Category:$source");
	$self->{wiki_base} = $wiki_base;
	$self->{query} = "/w/api.php?action=query&format=yaml"
			. "&list=categorymembers&cmsort=timestamp&cmdir=desc&cmlimit=".$max_new_news
			."&cmtitle=$source";
	return $self;
}

sub fetch_titles {
	my ($self) = @_;
	my $parsed_response = Derbeth::MediaWikiApi::query($self->{wiki_base}, $self->{query});
	unless ($parsed_response) {
		$self->report_fetch_failure("Failed to get members of category ".encode_utf8($self->{source}));
		return ();
	}
	return map { $_->{title} } @{$parsed_response->{query}->{categorymembers}};
}

1;
