package RSS::FeedDefinitionReader;
use strict 'vars';
use utf8;

use RSS::Feed;
use RSS::NewsSource;
use RSS::Settings;
use YAML::Syck qw'LoadFile';
use Derbeth::Web;

$YAML::Syck::ImplicitUnicode = 1;

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
	my @defs;
	foreach my $doc (@{$all->{sources}}) {
		my $feed = new RSS::Feed($doc->{output_file},
			$doc->{title},
			$doc->{page_url},
			$doc->{description},
			$doc->{language},
			$doc->{feed_link});
		$feed->setImage($doc->{logo}->{url},
			$doc->{title},
			$doc->{page_url},
			$doc->{logo}->{width},
			$doc->{logo}->{height});
		$feed->setCopyright($doc->{copyright});

		my $check_interval = $doc->{check_interval};
		$check_interval = $RSS::Settings::FORCED_FEED_CHECK_INTERVAL if $RSS::Settings::FORCED_FEED_CHECK_INTERVAL;
		my $link_prefix = $doc->{link_prefix} || "http://$doc->{domain}";
		my $max_new_news = $doc->{max_new_news} || $RSS::Settings::DEFAULT_MAX_NEW_NEWS;

		my $news_source = new RSS::NewsSource($check_interval,
			$link_prefix,
			$doc->{domain},
			$doc->{source},
			$doc->{source_type},
			$max_new_news);

		push @defs, {'feed' => $feed, 'news_source' => $news_source};
	}
	return @defs;
}

1;
