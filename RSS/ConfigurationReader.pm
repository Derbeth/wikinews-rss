package RSS::ConfigurationReader;
use strict;
use utf8;

use RSS::Feed;
use RSS::NewsResolver;
use RSS::NewsSource;
use RSS::Settings;
use RSS::VulgarismDetector;
use YAML::Any qw'LoadFile';
use Derbeth::Web;

if (YAML::Any->implementation eq 'YAML::Syck') {
	$YAML::Any::ImplicitUnicode = 1;
}

sub new {
	my ($class, $source) = @_;
	my $self = {};
	bless($self, $class);
	return $self;
}

sub read_feeds {
	my ($self, $source) = @_;

	my $all = LoadFile($source) || die "cannot read $source";
	my $domains = $all->{domains};
	my @defs;
	foreach my $doc (@{$all->{sources}}) {
		my $domain = $domains->{$doc->{domain}} || die "invalid domain: $doc->{domain}";
		my $feed = new RSS::Feed($doc->{output_file},
			$doc->{title},
			$doc->{page_url},
			$doc->{description},
			$domain->{language},
			$doc->{feed_link});
		$feed->setImage($doc->{logo}->{url},
			$doc->{title},
			$doc->{page_url},
			$doc->{logo}->{width},
			$doc->{logo}->{height});
		$feed->setCopyright($domain->{copyright});

		my $check_interval = $doc->{check_interval};
		$check_interval = $RSS::Settings::FORCED_FEED_CHECK_INTERVAL if $RSS::Settings::FORCED_FEED_CHECK_INTERVAL;
		my $link_prefix = $domain->{link_prefix} || "http://$domain->{domain}";
		my $max_new_news = $doc->{max_new_news} || $RSS::Settings::DEFAULT_MAX_NEW_NEWS;

		my $news_source = new RSS::NewsSource($check_interval,
			$link_prefix,
			$domain->{domain},
			$doc->{source},
			$doc->{source_type},
			$max_new_news);

		my $news_resolver = new RSS::NewsResolver($link_prefix);

		push @defs, {'feed' => $feed, 'news_source' => $news_source, 'news_resolver' => $news_resolver};
	}
	return @defs;
}

sub create_vulgarism_detector {
	my ($self, $source) = @_;
	my @vulg_arr = LoadFile($source) || die "cannot read $source";
	return new RSS::VulgarismDetector(@vulg_arr);
}

1;
