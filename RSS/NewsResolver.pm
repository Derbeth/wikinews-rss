package RSS::NewsResolver;
use strict;
use utf8;

use Encode;
use Derbeth::MediaWikiApi;
use RSS::Settings;
use URI::Escape qw/uri_escape_utf8/;

my $BULK_QUERY = 1;

sub new {
	my ($class, $wiki_base) = @_;
	my $self = {};
	bless($self, $class);
	$self->{wiki_base} = $wiki_base;
	$self->{query_base} = "/w/api.php?action=query&format=json";
	return $self;
}

sub fetch_details {
	my ($self, @articles) = @_;

	my $order = $RSS::Settings::DATE_FROM_NEWEST_REVISION ? 'older' : 'newer';
	my %info_responses = $self->query_articles("&prop=info&inprop=url", @articles);
	# revisions supports limit only for 1 page
	my %revisions_responses = $self->query_each("&prop=revisions&rvprop=timestamp&rvdir=$order&rvlimit=1", @articles);
	foreach my $article (@articles) {
		$article->{fetch_error} = 0;
		my $info_response = $info_responses{$article->{title}};
		my $revisions_response = $revisions_responses{$article->{title}};

		if ($info_response && $revisions_response) {
			$article->parse_info_response($info_response);
			$article->parse_revisions_response($revisions_response);
		} else {
			$article->{fetch_error} = 1;
		}
	}
}

sub check_refresh {
	my ($self, @articles) = @_;

	my %page_responses = $self->query_articles("&prop=info", @articles);
	my @refreshed;
	foreach my $article (@articles) {
		print "Checking if needs refresh: ", encode_utf8($article->toString(1)), "\n" if $RSS::Settings::DEBUG_MODE;

		my $info_response = $page_responses{$article->{title}};
		unless ($info_response) {
			print "Cannot refresh ", encode_utf8($article->{title}), " - page missing?\n";
			next;
		}
		if ($article->needs_refresh($info_response)) {
			push @refreshed, $article;
		}
	}

	foreach my $article (@refreshed) {
		$self->fetch_summary($article);
	}

	return @refreshed;
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

sub query_articles {
	my ($self, $query_params, @articles) = @_;
	die unless @articles;
	return $BULK_QUERY ? $self->query_all($query_params, @articles) : $self->query_each($query_params, @articles);
}

sub query_all {
	my ($self, $query_params, @articles) = @_;
	my $titles = join('|', map { uri_escape_utf8($_->{title}) } @articles);
	my $query = $self->{query_base}.$query_params."&titles=".$titles;
	return get_all_pages_hash(Derbeth::MediaWikiApi::query($self->{wiki_base}, $query));
}

sub query_each {
	my ($self, $query_params, @articles) = @_;
	my %page_responses;
	foreach my $article (@articles) {
		my $query = $self->{query_base}.$query_params."&titles=".uri_escape_utf8($article->{'title'});

		my $page_response = get_single_page_hash(Derbeth::MediaWikiApi::query($self->{wiki_base}, $query));
		$page_responses{$article->{title}} = $page_response if $page_response;
	}
	return %page_responses;
}

sub get_single_page_hash {
	my ($parsed) = @_;
	return undef unless defined $parsed;
	my @pages = values(%{$parsed->{query}->{pages}});
	return $pages[0];
}

sub get_all_pages_hash {
	my ($parsed) = @_;
	return undef unless defined $parsed;
	my @pages = values(%{$parsed->{query}->{pages}});
	my %pages_hashes;
	foreach my $page (@pages) {
		$pages_hashes{$page->{title}} = $page;
	}
	return %pages_hashes;
}

1;
