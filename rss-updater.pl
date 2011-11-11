#!/usr/bin/perl -w
#
# Program: rss-updater.pl
#   Updates RSS feed of Wikinews
#
# Parameters:
#   none
#
# Author:
#   Derbeth, <http://derbeth.w.interia.pl/>, <derbeth@interia.pl>,
#            [[n:pl:User:Derbeth]]
#
# Licence:
#   3-clause BSD, <http://www.opensource.org/licenses/bsd-license.php>
#   GPL sucks!
#
# Programming language:
#   Perl 5
#
# Platform:
#   cross-platform
#
# Documentation standard:
#   NaturalDocs, <http://www.naturaldocs.org/>
#
# Coding standard:
#   Awful.
#
# Encoding:
#   UTF-8

use Encode;

use NewsHeadline;
use NewsList;
use NewsManager;
use Feed;
use Settings;
use Status;

use strict 'vars';

############################################################################
# Section: Settings 
#   Program settings
#
# See also:
#   - <NewsHeadline::$MAX_SUMMARY_LEN> and <NewsHeadline::@VULGARISMS>
#   - <NewsManager::$WAIT_TIME>, <NewsManager::$MAX_PENDING> and <NewsManager::$MAX_SAVED>
#   - <Feed::$MAX_ENTRIES>
############################################################################

# Const: $MAX_NEW_NEWS
#   how many news are fetched from list
#
# See also:
#   <NewsManager::$MAX_PENDING>, <NewsManager::$MAX_SAVED>,
#   <Feed::$MAX_ENTRIES>
my $MAX_NEW_NEWS = 15;

# Const: $NEWS_LIST_URL
#   URL to list of news
my $NEWS_LIST_URL = 'http://pl.wikinews.org/w/index.php?title=Szablon:Najnowsze_wiadomo%C5%9Bci';

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

Derbeth::Web::set('DOWNLOAD_METHOD','post');
Derbeth::Web::set('USER_AGENT','DerbethBot/beta (Linux) Opera rulez');


############################################################################
# Section: Functions
############################################################################

# Variable: $fetch_failures
#   internal variable, counts fetch failures for <fetch_news_list()>
my $fetch_failures = 0;

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
	#my $input_file = 'latestnews.htm';
	
	#open(FILE,$input_file) or die "cannot open file $input_file";
	#my $retval;
   #my $c = <FILE>;
   #while($c) { $retval .= $c; $c=<FILE>; }
   #return get_content($retval);
	my $error_msg = '';

	Derbeth::Web::purge_page($NEWS_LIST_URL);
	my $page = Derbeth::Wikipedia::pobierz_zawartosc_strony($NEWS_LIST_URL);

	if( $page eq '' ) { $error_msg = "cannot fetch news list from server"; }
	if( Derbeth::Wikipedia::jest_redirectem($page) ) { $error_msg = "redirect instead of news list";}
	if(! Derbeth::Wikipedia::strona_istnieje($page) ) { $error_msg = "news list: page does not exist"; }

	if( $error_msg ne '' ) {
		my $now = localtime();
		print "$now:  $error_msg\n";
		if( ++$fetch_failures >= $MAX_FETCH_FAILURES ) {
			set_status(2);
			die "too many errors ($fetch_failures)";
		}
		return '';
	}

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
	my $retval = new NewsList;
	
	open(OUT, ">$Settings::HEADLINES_FILE");
	print OUT encode_utf8($content);
	close(OUT);
	if( $content eq '' ) { return $retval; }
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
	my @titles; # for debug
	
	while( 1 ) {
		if( $content =~ /<a href=(.+?)<\/a>/ )
		{
			$content = $'; # POSTMATCH
			
			my $whole_link = $1;
			if( $whole_link =~ /^"([^">]+)"[^>]*>(.*)/ && $whole_link !~ /class="new"/)
			{
				my($m1,$m2)=($1,$2);
				#print "|$1|$2|$3|\n"; #DEBUG "
				my $news_headline = new NewsHeadline($m2,$Settings::LINK_PREFIX.$m1);
				#print $news_headline->toString() . "\n"; # DEBUG
				$retval->add($news_headline);
				
				push @titles, $m2;
				if( ++$count >= $MAX_NEW_NEWS ) { last; } # end after adding $MAX_NEW_NEWS news
			}
		} else {
			last;
		}
	}
	
	$retval->reverseList(); # oldest news first
	if ($Settings::DEBUG_MODE) {
		print STDERR "Fetched ", scalar(@titles), " news: ", join(' ', map {"`$_'"} @titles), "\n";
	}
	
	return( $retval );
}

my $loop_count=1;
sub clear_errors
{
	$loop_count=($loop_count+1) % $ERROR_CLEAR_DELAY;
	if( $loop_count == 0 && $fetch_failures > 0 ) {
		--$fetch_failures;
	}
}

############################################################################
# Section: Main
############################################################################

# sets close event handler
$SIG{INT} = $SIG{TERM} = sub { Status::set_status(2); exit; };
# sets crash event handler
$SIG{__DIE__} = sub { print @_; Status::set_status(3); exit; };

Status::set_status(0); # started

my $feed = new Feed($Settings::OUTPUT_FILE,'Wikinews Polska','http://pl.wikinews.org/',
	'Kana&#322; RSS Wikinews Polska');
$feed->setImage('http://upload.wikimedia.org/wikipedia/commons/thumb/b/bd/Wikinews-logo-en.png/120px-Wikinews-logo-en.png',
	'Wikinews Polska','http://pl.wikinews.org/',120,92);
$feed->setCopyright('Zawarto&#347;&#263; Wikinews Polska dost&#281;pna na licencji '
	. 'Creative Commons 2.5 Uznanie Autorstwa (http://creativecommons.org/licenses/by/2.5/)');
my $news_manager = new NewsManager($feed);

print "rss-updater version $Settings::VERSION running. Hit Control+C to exit.\n\n";

while( 1 ) {
	my $news_list = fetch_news_list();
	
	my $news_headlines = retrieve_news_headlines($news_list);

	$news_manager->processNewNews($news_headlines);
	
	clear_errors();
	
	sleep(60 * $Settings::CHECKOUT_PAUSE);
}

