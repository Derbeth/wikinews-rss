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
	#pop @_;
	my $feed_ref = \pop @_;
	
	my $self = {};
   bless($self, "NewsManager");

   $self->{'pending'} = new NewsList($MAX_PENDING); # news waiting for confirmation
   $self->{'saved'} = new NewsList($MAX_SAVED);     # list already saved in feed
   $self->{'feed'} = $feed_ref;

   $self->{'feed_changed'} = 0; # if something new was added, is set to 1
                                # and feed is saved to disk

   return $self;
}

# Function: processNewNews
#
# Parameters:
#   $new - list of new news, object of class <NewsList>
sub processNewNews {
	my($self, $new) = @_;
	
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
	$iterator = $self->{'saved'}->getIterator();
	while( $iterator->hasNext() == 1 )
	{
		my $news = $iterator->getNext();
		if( !$new->contains($news) ) { push @to_remove, $news; }
	}
	foreach my $news (@to_remove) {
		$self->removeNews($news);
	}
	
	$self->{'pending'}->removeOlderThan($Settings::NEWS_ACCEPT_TIME);
	
	if( $self->{'feed_changed'} == 1 )
	{
		$self->{'last_saved'} = scalar(localtime());
		${$self->{'feed'}}->save();
	}

	set_status(1, $self->{'last_saved'});
	if ($Settings::DEBUG_MODE) {
		print "\n", scalar(localtime()), ' ';
		print "Accepted: ", $self->{'saved'}->toString(1), "\n";
		print "Pending: ", $self->{'pending'}->toString(1), "\n";
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
	
	$news->fetchSummary();
	
	if( !$news->wasCensored() )
	{
		${$self->{'feed'}}->addEntry( $news->{'title'}, $news->getDate(), $news->{'link'},
			$news->getSummary() );
	
		$self->{'feed_changed'} = 1;
	}
}

sub addPending {
	my($self,$news) = @_;
	
	$self->{'pending'}->add($news);
}

sub removeNews {
	my($self,$news) = @_;
	
	$self->{'saved'}->remove($news);
	${$self->{'feed'}}->removeEntry($news->{'title'});
	$self->{'feed_changed'} = 1;
}

1;

