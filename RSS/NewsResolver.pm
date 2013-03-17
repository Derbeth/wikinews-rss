package RSS::NewsResolver;
use strict;
use utf8;

sub new {
	my ($class, $wiki_base) = @_;
	my $self = {};
	bless($self, $class);
	$self->{wiki_base} = $wiki_base;
	$self->{query_base} = "/w/api.php?action=query&format=yaml";
	return $self;
}

sub fetch_details {
	my ($self, @articles) = @_;
	
	foreach my $article (@articles) {
		$article->{fetch_error} = 0;
		my $title_escaped = uri_escape_utf8($article->{'title'});
		my $info_query = $self->{query_base}."&prop=info&inprop=url&titles=".$title_escaped;
		my $order = $RSS::Settings::DATE_FROM_NEWEST_REVISION ? 'older' : 'newer';
		my $revisions_query = $self->query_base."&prop=revisions&rvprop=timestamp&rvdir=$order&rvlimit=1&titles=".$title_escaped;
		
		my $parsed_info = get_single_page_hash(Derbeth::MediaWikiApi::query($self->{wiki_base}, $info_query));
		my $parsed_revisions = get_single_page_hash(Derbeth::MediaWikiApi::query($self->{wiki_base}, $revisions_query));
		
		if ($parsed_info && $parsed_revisions) {
			$article->parse_info_response($parsed_info);
			$article->parse_revisions_response($parsed_revisions);
		} else {
			$article->{fetch_error} = 1;
		}
	}
}

sub fetch_summary {
	my ($self, $article) = @_;
	my $page_text = Derbeth::MediaWikiApi::rendered_page($self->{wiki_base}, $article->{title});
	if (defined $page_text) {
		$article->process_page_text($page_text);
	} else {
		$article->{fetch_error} = 1;
	}
}

sub get_single_page_hash {
	my ($parsed) = @_;
	return undef unless defined $parsed;
	my @pages = values(%{$parsed->{pages}});
	return $pages[0];
}

1;
