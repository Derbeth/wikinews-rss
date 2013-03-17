# Package: Settings
#   stores settings for whole project
package RSS::Settings;

use strict;
use utf8;

use Exporter;

use vars qw($ADMIN_MAIL $FORCED_FEED_CHECK_INTERVAL $DATE_FROM_NEWEST_REVISION
	$DEBUG_MODE
	$READ_LIST_FROM_FILE $HEADLINES_FILE
	$MAX_ENTRIES $DEFAULT_MAX_NEW_NEWS $NEWS_ACCEPT_TIME
	$PURGE_NEWS_LIST $STATUS_FILE $VERSION);

# Const: $VERSION
#   program version
$VERSION = '0.8.0';

# Const: $DEBUG_MODE
#   setting to true causes more diagnostic messages to be printed
$DEBUG_MODE = 0;

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
$DEFAULT_MAX_NEW_NEWS = 15;

# Const: $CHECKOUT_PAUSE
#   pause between checking list of current news (in minutes)
#
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

# Const: $PURGE_NEWS_LIST
# if true, on each check the bot will clear MediaWiki cache for the page
# containing news list
$PURGE_NEWS_LIST = 1;

sub set_debug_mode {
	$PURGE_NEWS_LIST = 0;
	$FORCED_FEED_CHECK_INTERVAL = 1;
	$NEWS_ACCEPT_TIME = 1;

	$DEBUG_MODE = 1;
	# $READ_LIST_FROM_FILE = 1;

	print STDERR "Debug settings used\n";
}

1;
