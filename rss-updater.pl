#!/usr/bin/perl -w
#
# Program: rss-updater.pl
#   Updates RSS feed of Wikinews
#
# Version:
#   0.4.5
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

use NewsHeadline;
use NewsList;
use NewsManager;
use Feed;
use Settings;

use Net::SMTP; 

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

# Const: $OUTPUT_FILE
#   path where generated RSS file should be placed
my $OUTPUT_FILE = '../public_html/wikinews.xml';

# Const: $STATUS_FILE
#   path to HTML file where bot writes its current status
#
#   If variable is empty, status is not written.
my $STATUS_FILE = '../public_html/status.html';


# Const: $CHECKOUT_PAUSE
#   pause between checking list of current news (in minutes)
#
# Description:
#   Gives editors time to correct mistakes, delete vandalism etc.
#   After $CHECKOUT_PAUSE news from list is added to queue and after
#   another $CHECKOUT_PAUSE it is either accepted (if it is still on list
#   received from server) or deleted (if it is not on the list).
#   So editors have 2 * $CHECKOUT_PAUSE minutes to correct mistakes.
#
# See also:
#   <NewsManager::$WAIT_TIME>: both values should be synchronised
my $CHECKOUT_PAUSE = 5;

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

# Var: $ADMIN_MAIL
#   Mail address used to contact bot administrator
my $ADMIN_MAIL = 'der'.'beth.fora' . '@w'.'p.pl';

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

# Function: notify_admin
#   sends and e-mail notifying administrator of bot crash
sub notify_admin {
	open(MAIL, "|/usr/lib/sendmail -t");

   print MAIL "To: $ADMIN_MAIL\n";
   print MAIL "From: $ENV{USER}\n";
   print MAIL "Subject: RSS bot dead\n";

   print MAIL "Wikinews RSS bot is dead.\n";

   close (MAIL);
}


# Function: set_status
#   set status: running or failure, saves it to a HTML file
#
# Parametrs:
#   $running - see below
#
# Status:
#   0 - running
#   1 - stopped (closed)
#   2 - dead (on error)
sub set_status {
	my $running = pop @_;
#	print "ELO\n";
	if( $STATUS_FILE eq '') { return; } # no status file
	
	my $desc;
	
	unless( open(STATUS, "> $STATUS_FILE") ) {
		print "cannot open status file for writing\n";
		##$STATUS_FILE = ''; # prevent from next attempts to write to the file
		return;
	}
	print STATUS '<html><head><title>Wikinews RSS bot status</title></head><body><p><strong>';
	
	SWITCH: {
		if( $running == 0 )  {
			print STATUS 'RUNNING'; $desc = "bot ok";
			last SWITCH;
		}
		if( $running == 1 ) {
			print  STATUS 'STOPPED'; $desc = "bot was stopped or system was closed";
			last SWITCH;
		}
		print STATUS 'DEAD'; $desc = "bot terminated because of an error";
	}
	
	print STATUS "</strong></p><p>$desc</p>";
	print STATUS '</body></html>';

	close STATUS;
	
	if( $running == 2 ) { notify_admin(); }
}
	

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
	
	open(OUT, ">last_headlines.xml");
	print OUT $content;
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
	#print STDERR scalar(@titles), " news: ", join(' ', map {"`$_'"} @titles), "\n"; # debug
	
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
$SIG{INT} = $SIG{TERM} = sub { set_status(1); exit; };
# sets crash event handler
$SIG{__DIE__} = sub { print @_; set_status(2); exit; };

set_status(0); # running

my $feed = new Feed($OUTPUT_FILE,'Wikinews Polska','http://pl.wikinews.org/',
	'Kana&#322; RSS Wikinews Polska');
$feed->setImage('http://upload.wikimedia.org/wikipedia/commons/thumb/b/bd/Wikinews-logo-en.png/120px-Wikinews-logo-en.png',
	'Wikinews Polska','http://pl.wikinews.org/',120,92);
$feed->setCopyright('Zawarto&#347;&#263; Wikinews Polska dost&#281;pna na licencji '
	. 'Creative Commons 2.5 Uznanie Autorstwa (http://creativecommons.org/licenses/by/2.5/)');
my $news_manager = new NewsManager($feed);

print "rss-updater version $Settings::VERSION running. Hit Control+C to exit.\n\n";

while( 1 ) {
	my $news_list = fetch_news_list(); # http://pl.wikinews.org/wiki/Szablon:Najnowszewiadomoci
	
	my $news_headlines = retrieve_news_headlines($news_list);

	$news_manager->processNewNews($news_headlines);
	
	clear_errors();
	
	sleep(60 * $CHECKOUT_PAUSE);
}

