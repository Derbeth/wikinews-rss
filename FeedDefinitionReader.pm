package FeedDefinitionReader;
use strict 'vars';
use utf8;

use Feed;
use NewsSource;
use Settings;

sub new {
	my ($class) = @_;
	my $self = {};
	bless($self, $class);

	return $self;
}

sub read {
	my ($self) = @_;

	my $feed = new Feed($Settings::OUTPUT_FILE, $Settings::FEED_TITLE, $Settings::PAGE_URL,
		$Settings::FEED_DESCRIPTION, $Settings::FEED_LANGUAGE, $Settings::FEED_LINK);
	$feed->setImage($Settings::LOGO_URL, $Settings::FEED_TITLE, $Settings::PAGE_URL,
		$Settings::LOGO_WIDTH, $Settings::LOGO_HEIGHT);
	$feed->setCopyright($Settings::FEED_COPYRIGHT);
	my $check_interval = $Settings::CHECKOUT_PAUSE;
	$check_interval = $Settings::FORCED_FEED_CHECK_INTERVAL if $Settings::FORCED_FEED_CHECK_INTERVAL;
# 	my $news_source = new NewsSource($check_interval, $Settings::LINK_PREFIX, $Settings::NEWS_LIST_PAGE);
	my $news_source = new NewsSource($check_interval, $Settings::LINK_PREFIX, 'Nauka', 'CATEGORY');

	my $def = {'feed' => $feed, 'news_source' => $news_source};

	return ($def);
}

1;
