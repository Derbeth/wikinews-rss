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
use NewsListIterator;
use NewsList;
use Settings;
use Status;
use Derbeth::Web 0.5.0;

use Encode;

####################################
# Group: Settings
####################################

# Const: $MAX_FETCH_FAILURES
#   how many fetch failures can be tollerated
my $MAX_FETCH_FAILURES = 20;

# Const: $ERROR_CLEAR_DELAY
#   after n main loops error count will be decreased by one
#   As result, every ($CHECKOUT_PAUSE * $ERROR_CLEAR_DELAY) minutes error number
#   will be reduced by one
#
#   Should be greater than $MAX_FETCH_FAILURES
my $ERROR_CLEAR_DELAY=20;

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
	my ($class, $feed_ref, $news_list_url, $check_interval_mins) = @_;

	my $self = {};
	bless($self, "NewsManager");

	$self->{'pending'} = new NewsList($MAX_PENDING); # news waiting for confirmation
	$self->{'saved'} = new NewsList($MAX_SAVED);     # list already saved in feed
	$self->{'feed'} = $feed_ref;

	$self->{'feed_changed'} = 0; # if something new was added, is set to 1 and feed is saved to disk

	$self->{'news_list_url'} = $news_list_url;

	# internal variable, counts fetch failures for <fetch_news_list()>
	$self->{'fetch_failures'} = 0;
	$self->{'loop_count'}=1;
	$self->{'ticks'} = 0;
	$self->{'check_interval_mins'} = $check_interval_mins;

	return $self;
}

sub tick {
	my ($self) = @_;
	if ($self->{'ticks'} % $self->{'check_interval_mins'} == 0) {
		$self->processNewNews(retrieve_news_headlines($self->fetch_news_list()));

		$self->clear_errors();
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

	$news->fetchDetails();

	if( !$news->wasCensored() )
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
	$self->{'feed'}>removeEntry($news->{'title'});
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

# Function: fetch_news_list
#   gets list of latest news from server
#
# Parameters:
#   none
#
# Returns:
#   string with content of HTML file
#
# Remarks:
#   function counts number of cases where news list cannot be fetched from
#   server. If it exceeds <$MAX_FETCH_FAILURES>, script dies.
sub fetch_news_list {
	my($self) = @_;
	if ($Settings::READ_LIST_FROM_FILE) {
		my $input_file = $Settings::HEADLINES_FILE;
		print "Reading new list from file $input_file\n";
		open(FILE,$input_file) or die "cannot read news list: $!";
		my @lines = <FILE>;
		close(FILE);
		my $content = join('', @lines);
		return decode_utf8($content);
	}
	my $error_msg = '';

	Derbeth::Web::purge_page($self->{'news_list_url'}) if $Settings::PURGE_NEWS_LIST;
	my $page = decode_utf8(Derbeth::Wikipedia::get_page($self->{'news_list_url'}));

	if( $page eq '' ) { $error_msg = "cannot fetch news list from server"; }
	if( Derbeth::Wikipedia::jest_redirectem($page) ) { $error_msg = "redirect instead of news list";}
	if(! Derbeth::Wikipedia::strona_istnieje($page) ) { $error_msg = "news list: page does not exist"; }

	if( $error_msg ne '' ) {
		my $now = localtime();
		print "$now:  $error_msg\n";
		if( ++$self->{fetch_failures} >= $MAX_FETCH_FAILURES ) {
			Status::set_status(2);
			die "too many errors ($self->{fetch_failures})";
		}
		return '';
	}

	open(OUT, ">$Settings::HEADLINES_FILE");
	print OUT encode_utf8($page);
	close(OUT);
	return $page;
}

# Function: retrieve_news_headlines
#   retrieves news headlines from news list
#
# Parameters:
#   $bare_list - HTML file with list of news
#
# Returns:
#   list of <NewsHeadline> objects
#
# Remarks:
#   reads only first <$MAX_NEW_NEWS> links
sub retrieve_news_headlines {
	my $content = pop @_;

	if( $content eq '' ) { return (); }
	if ($content =~ /<!-- *(bodytext|bodycontent|start content) *-->/) {
		$content = $';
	} else {
		print STDERR "WARN: cannot cut off begin\n";
	}
	if ($content =~ /<div class="printfooter">/) {
		$content = $`;
	} else {
		print STDERR "WARN: cannot cut off end\n";
	}

	my $count = 0;
	my @titles;

	while( 1 ) {
		if( $content =~ /<a href=(.+?)<\/a>/ )
		{
			$content = $'; # POSTMATCH

			my $whole_link = $1;
			if( $whole_link =~ /^"([^">]+)"[^>]*>(.*)/ && $whole_link !~ /class="new"/)
			{
				my($m1,$m2)=($1,$2);
				push @titles, $m2;
				if( ++$count >= $Settings::MAX_NEW_NEWS ) { last; } # end after adding $MAX_NEW_NEWS news
			}
		} else {
			last;
		}
	}

	if ($Settings::DEBUG_MODE) {
		print STDERR "Fetched ", scalar(@titles), " news: ", join(' ', map {encode_utf8("`$_'")} @titles), "\n";
	}

	return @titles;
}


sub clear_errors
{
	my($self) = @_;
	$self->{loop_count}=($self->{loop_count}+1) % $ERROR_CLEAR_DELAY;
	if( $self->{loop_count} == 0 && $self->{fetch_failures} > 0 ) {
		--$self->{fetch_failures};
	}
}

1;
