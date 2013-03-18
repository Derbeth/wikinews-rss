# Class: NewsManager
#   class deciding which news can be saved in feed
package RSS::NewsManager;
use strict 'vars';

use RSS::Feed;
use RSS::NewsHeadline;
use RSS::NewsList;
use RSS::Settings;
use RSS::Status;

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
	my ($class, $feed_ref, $news_source, $news_resolver, $vulgarism_detector) = @_;

	my $self = {};
	bless($self, $class);

	$self->{'pending'} = new RSS::NewsList($MAX_PENDING); # news waiting for confirmation
	$self->{'saved'} = new RSS::NewsList($MAX_SAVED);     # list already saved in feed
	$self->{'feed'} = $feed_ref;
	$self->{'news_source'} = $news_source;
	$self->{'news_resolver'} = $news_resolver;
	$self->{'vulgarism_detector'} = $vulgarism_detector;

	$self->{'feed_changed'} = 0; # if something new was added, is set to 1 and feed is saved to disk

	return $self;
}

sub tick {
	my ($self) = @_;
	if ($self->{'news_source'}->tick()) {
		$self->processNewNews($self->{'news_source'}->fetch_titles());
	}
}

# Function: processNewNews
#
# Parameters:
#   @titles - list of titles of new news
sub processNewNews {
	my($self, @titles) = @_;

	my $new = new RSS::NewsList;
	foreach my $title (@titles) {
		$new->add(new RSS::NewsHeadline($self->{news_source}, $title));
	}
	$new->reverseList(); # oldest first

	$self->{'feed_changed'} = 0;

	my @to_save;
	foreach my $news (@{$new->{news}})
	{
		if( $self->{'pending'}->contains($news) && $self->{'pending'}->getAgeMinutes($news) >= $RSS::Settings::NEWS_ACCEPT_TIME )
		{
			push @to_save, $news;

		} elsif( ! $self->{'pending'}->contains($news) && ! $self->{'saved'}->contains($news) )
		{
			$self->addPending($news);
		}
	}
	$self->saveNews(@to_save);

	my @to_remove; # news to be removed from feed
	my @to_refresh;
	foreach my $news (@{$self->{saved}->{news}})
	{
		if( !$new->contains($news) ) {
			push @to_remove, $news;
		} else {
			push @to_refresh, $news;
		}
	}
	foreach my $news (@to_remove) {
		$self->removeNews($news);
	}

	$self->{'pending'}->removeOlderThan($RSS::Settings::NEWS_ACCEPT_TIME);

	if( $self->{'feed_changed'} == 1 )
	{
		# to minimize number of requests to server, we refresh only if there are changes now
		# and if there was a successful save before
		if ($self->{'last_saved'}) {
			$self->refreshNews(@to_refresh);
		}
		$self->{'last_saved'} = scalar(localtime());
		$self->{'feed'}->save();
	}

	set_status(1, $self->{'last_saved'});
	if ($RSS::Settings::DEBUG_MODE) {
		print "\n", scalar(localtime()), ' ', encode_utf8($self->{news_source}->{source}), ' | ';
		print "Accepted: [", encode_utf8($self->{'saved'}->toString(1)), "]\n";
		print "Pending: [", encode_utf8($self->{'pending'}->toString(1)), "]\n";
	}
}

# Function: saveNews
#   fetches news summary, removes news from pending, adds news to saved list and
#   news feed
#
#   If news is vulgar, it won't be added to the news feed.
sub saveNews {
	my($self, @to_save) = @_;
	return unless @to_save;

	$self->{news_resolver}->fetch_details(@to_save);

	foreach my $news (@to_save) {
		$self->{'pending'}->remove($news);
		$self->{'saved'}->add($news);

		$self->{news_resolver}->fetch_summary($news) unless $news->{fetch_error};

		if ($news->{fetch_error}) {
			print "Won't add ", encode_utf8($news->{'title'}), " because its text cannot be fetched.\n";
		} elsif( my $vulgarism = $news->wasCensored($self->{vulgarism_detector}) ) {
			print "Won't add ", encode_utf8($news->{'title'}), ": contains vulgarism '$vulgarism'\n";
		} else {
			$self->{'feed'}->addEntry( $self->newsToFeed($news) );
			$self->{'feed_changed'} = 1;
		}
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
	my($self,@to_refresh) = @_;
	return unless @to_refresh;
	my @refreshed = $self->{news_resolver}->check_refresh(@to_refresh);
	foreach my $news (@refreshed) {
		print "Refreshing news: ", encode_utf8($news->toString(1)), "\n";
		$self->{'feed'}->replaceEntry( $self->newsToFeed($news) );
		$self->{'feed_changed'} = 1;
	}
}

1;
