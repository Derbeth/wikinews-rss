# Class: NewsManager
#   class deciding which news can be saved in feed
#
# Project:
#   feed-updater (see for license & other info)
#
# Author:
#   Derbeth, <http://derbeth.w.interia.pl/>, <derbeth@interia.pl>
#            [[n:pl:User:Derbeth]]

package NewsManager;
use strict 'vars';

use Feed;
use NewsHeadline;
use NewsListIterator;
use NewsList;
use Settings;
use Status;
use Derbeth::Web 0.5.0;

use Encode;

####################################
# Group: Settings
####################################

# Const: $MAX_PENDING
#   how many entries can wait in pending queue
#   if more news are added, oldest news in queue are deleted
my $MAX_PENDING = 30;

# Const: $MAX_SAVED
#   how many saved entries are remembered
#   must be at least as big as size of Feed (see <$MAX_ENTRIES>)
my $MAX_SAVED = 30;

####################################
# Group: Functions
####################################

sub new {
	my ($class, $feed_ref, $news_source, $check_interval_mins) = @_;

	my $self = {};
	bless($self, "NewsManager");

	$self->{'pending'} = new NewsList($MAX_PENDING); # news waiting for confirmation
	$self->{'saved'} = new NewsList($MAX_SAVED);     # list already saved in feed
	$self->{'feed'} = $feed_ref;
	$self->{'news_source'} = $news_source;

	$self->{'feed_changed'} = 0; # if something new was added, is set to 1 and feed is saved to disk

	$self->{'ticks'} = 0;
	$self->{'check_interval_mins'} = $check_interval_mins;

	return $self;
}

sub tick {
	my ($self) = @_;
	if ($self->{'ticks'} % $self->{'check_interval_mins'} == 0) {
		$self->processNewNews($self->{'news_source'}->fetch_titles());
	}
	++$self->{'ticks'};
}

# Function: processNewNews
#
# Parameters:
#   @titles - list of titles of new news
sub processNewNews {
	my($self, @titles) = @_;

	my $new = new NewsList;
	foreach my $title (@titles) {
		$new->add(new NewsHeadline($title));
	}
	$new->reverseList(); # oldest first

	$self->{'feed_changed'} = 0;

	my $iterator = $new->getIterator();
	while( $iterator->hasNext() == 1 )
	{
		my $news = $iterator->getNext();

		if( $self->{'pending'}->contains($news) && $self->{'pending'}->getAgeMinutes($news) > $Settings::NEWS_ACCEPT_TIME )
		{
			$self->saveNews($news);

		} elsif( ! $self->{'pending'}->contains($news) && ! $self->{'saved'}->contains($news) )
		{
			$self->addPending($news);
		}
	}

	my @to_remove; # news to be removed from feed
	my @to_refresh;
	$iterator = $self->{'saved'}->getIterator();
	while( $iterator->hasNext() == 1 )
	{
		my $news = $iterator->getNext();
		if( !$new->contains($news) ) {
			push @to_remove, $news;
		} else {
			push @to_refresh, $news;
		}
	}
	foreach my $news (@to_remove) {
		$self->removeNews($news);
	}

	$self->{'pending'}->removeOlderThan($Settings::NEWS_ACCEPT_TIME);

	if( $self->{'feed_changed'} == 1 )
	{
		# to minimize number of requests to server, we refresh only if there are changes
		foreach my $news (@to_refresh) {
			$self->refreshNews($news);
		}
		$self->{'last_saved'} = scalar(localtime());
		$self->{'feed'}->save();
	}

	set_status(1, $self->{'last_saved'});
	if ($Settings::DEBUG_MODE) {
		print "\n", scalar(localtime()), ' ';
		print "Accepted: ", encode_utf8($self->{'saved'}->toString(1)), "\n";
		print "Pending: ", encode_utf8($self->{'pending'}->toString(1)), "\n";
	}
}

# Function: saveNews
#   fetches news summary, removes news from pending, adds news to saved list and
#   news feed
#
#   If news is vulgar, it won't be added to the news feed.
sub saveNews {
	my($self, $news) = @_;

	$self->{'pending'}->remove($news);
	$self->{'saved'}->add($news);

	my $fetch_successful = $news->fetchDetails();

	if (!$fetch_successful) {
		print "Won't add ", encode_utf8($news->{'title'}), " because its text cannot be fetched.\n";
	} elsif( !$news->wasCensored() )
	{
		$self->{'feed'}->addEntry( $self->newsToFeed($news) );

		$self->{'feed_changed'} = 1;
	}
}

sub newsToFeed {
	my($self, $news) = @_;

	($news->{'title'}, $news->{'time'}, $news->{'link'}, $news->{'summary'}, $news->{'guid'})
}

sub addPending {
	my($self,$news) = @_;

	$self->{'pending'}->add($news);
}

sub removeNews {
	my($self,$news) = @_;

	$self->{'saved'}->remove($news);
	$self->{'feed'}->removeEntry($news->{'title'});
	$self->{'feed_changed'} = 1;
}

# checks if the news was changed on server since it was saved here, and
# marks it for refresh if needed
sub refreshNews {
	my($self,$news) = @_;
	if ($Settings::DEBUG_MODE) {
		print "Checking if needs refresh: ", encode_utf8($news->toString(1)), "\n";
	}
	if ($news->refresh()) {
		print "Refreshing news: ", encode_utf8($news->toString(1)), "\n";
		$self->{'feed'}->replaceEntry( $self->newsToFeed($news) );
		$self->{'feed_changed'} = 1;
	}
}

1;
