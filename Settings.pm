#!/usr/bin/perl
# Package: Settings
#   stores settings for whole project

package Settings;

use strict;
use utf8;

use Exporter;

use vars qw($ADMIN_MAIL $CHECKOUT_PAUSE $FORCED_FEED_CHECK_INTERVAL $DATE_FROM_NEWEST_REVISION
	$DEBUG_MODE $DOMAIN $FEED_COPYRIGHT $FEED_DESCRIPTION $FEED_LANGUAGE $FEED_LINK $FEED_TITLE
	$READ_LIST_FROM_FILE $HEADLINES_FILE $LINK_PREFIX $LOGO_URL $LOGO_HEIGHT $LOGO_WIDTH
	$MAX_ENTRIES $MAX_NEW_NEWS $NEWS_ACCEPT_TIME $NEWS_LIST_PAGE
	$OUTPUT_FILE $PAGE_URL $PURGE_NEWS_LIST $STATUS_FILE $VERSION);

# Const: $VERSION
#   program version
$VERSION = '0.8.0';

# Const: $DEBUG_MODE
#   setting to true causes more diagnostic messages to be printed
$DEBUG_MODE = 0;

# Const: $OUTPUT_FILE
#   path where generated RSS file should be placed
$OUTPUT_FILE = '../public_html/wikinews.xml';

# Const: $STATUS_FILE
#   path to HTML file where bot writes its current status
#
#   If variable is empty, status is not written.
$STATUS_FILE = '../public_html/status.html';

# Const: $HEADLINES_FILE
#   path to file where the HTML document with headline list is saved
$HEADLINES_FILE = 'last_headlines.xml';

# Const: $READ_LIST_FROM_FILE
#   if true, news list is read from local file $HEADLINES_FILE
$READ_LIST_FROM_FILE = 0;

# Const: $MAX_ENTRIES
#   maximal number of entries in feed
$MAX_ENTRIES = 17;

# Const: $MAX_NEW_NEWS
#   how many news are fetched from list
#
# See also:
#   <NewsManager::$MAX_PENDING>, <NewsManager::$MAX_SAVED>,
#   <$MAX_ENTRIES>
$MAX_NEW_NEWS = 15;

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
#   <$WAIT_TIME>: both values should be synchronised
$CHECKOUT_PAUSE = 5;

# if defined, will overwrite check interval for every feed
$FORCED_FEED_CHECK_INTERVAL = undef;

# Const: $NEWS_ACCEPT_TIME
#   time (in minutes) every news has to wait in pending list until it is removed as
#   outdated or saved as accepted
$NEWS_ACCEPT_TIME = 5;

# Const: $DATE_FROM_NEWEST_REVISION
#   if true, each news item will have the date of its newest revision
#   if false, each news item will have the date of its oldest revision
$DATE_FROM_NEWEST_REVISION = 1;

# Var: $ADMIN_MAIL
#   Mail address used to contact bot administrator
$ADMIN_MAIL = 'der'.'beth' . '@in'.'teria.pl';

# Const: $NEWS_LIST_URL
#   URL to list of news
# $NEWS_LIST_PAGE = 'Szablon:Najnowsze_wiadomo%C5%9Bci';
$NEWS_LIST_PAGE = 'Szablon:Najnowsze_wiadomości';

$LINK_PREFIX = 'http://pl.wikinews.org';

$FEED_TITLE = 'Wikinews Polska';

# Const: $FEED_LANGUAGE
#   ISO 639 code of the language the feed is written in
$FEED_LANGUAGE = 'pl';

$PAGE_URL = 'http://pl.wikinews.org/';

$DOMAIN = 'pl.wikinews.org';

$FEED_LINK = 'http://tools.wikimedia.pl/~derbeth/wikinews.xml';

$FEED_DESCRIPTION = 'Kanał RSS Wikinews Polska - wolnego serwisu informacyjnego tworzonego w technologii wiki (podobnie jak Wikipedia)';

$FEED_COPYRIGHT = 'Zawartość Wikinews Polska dostępna na licencji Creative Commons 2.5 Uznanie Autorstwa (http://creativecommons.org/licenses/by/2.5/)';

$LOGO_URL = 'http://upload.wikimedia.org/wikipedia/commons/thumb/b/bd/Wikinews-logo-en.png/120px-Wikinews-logo-en.png';

$LOGO_WIDTH = 120;

$LOGO_HEIGHT = 92;

# Const: $PURGE_NEWS_LIST
# if true, on each check the bot will clear MediaWiki cache for the page
# containing news list
$PURGE_NEWS_LIST = 1;

sub set_debug_mode {
	$Settings::PURGE_NEWS_LIST = 0;
	$Settings::FORCED_FEED_CHECK_INTERVAL = 1;
	$Settings::NEWS_ACCEPT_TIME = 1;

	$Settings::DEBUG_MODE = 1;
	# $Settings::READ_LIST_FROM_FILE = 1;

	print STDERR "Debug settings used\n";
}

1;
