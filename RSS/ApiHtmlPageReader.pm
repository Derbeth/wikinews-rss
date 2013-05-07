package RSS::ApiHtmlPageReader;
use strict;
use utf8;

use parent 'RSS::BaseHtmlPageReader';

use Derbeth::MediaWikiApi;
use URI::Escape;

sub new {
	my ($class, $wiki_base, $source, $max_new_news) = @_;
	my $self = $class->SUPER::new($max_new_news);
	$self->{wiki_base} = $wiki_base || die "required: wiki_base";
	$self->{source} = $source || die "required: source";
	return $self;
}

sub fetch_as_html_page {
	my($self) = @_;
	my $page_text = Derbeth::MediaWikiApi::rendered_page($self->{wiki_base}, $self->{source});
	unless (defined $page_text) {
		$self->report_fetch_failure("page does not exist: $self->{source}");
		return '';
	}
	return $page_text;
}

1;
