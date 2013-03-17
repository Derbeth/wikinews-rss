package RSS::FeedDefinitionReader;
use strict;
use utf8;

use RSS::Feed;
use RSS::NewsSource;
use RSS::Settings;
use YAML::Any qw'LoadFile';
use Derbeth::Web;

if (YAML::Any->implementation eq 'YAML::Syck') {
	$YAML::Any::ImplicitUnicode = 1;
}

sub new {
	my ($class, $source) = @_;
	my $self = {};
	bless($self, $class);
	$self->{'source'} = $source;
	return $self;
}

sub read {
	my ($self) = @_;

	open(my $fh, "<:encoding(UTF-8)", $self->{'source'}) || die "cannot read $self->{source}: $!";
	my $all = LoadFile($self->{'source'});
	close($fh);
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

		push @defs, {'feed' => $feed, 'news_source' => $news_source};
	}
	return @defs;
}

1;
