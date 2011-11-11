#!/usr/bin/perl
# Package: Settings
#   stores settings for whole project

package Settings;

use strict;
use Exporter;

use vars qw($ADMIN_MAIL $CHECKOUT_PAUSE $DATE_FROM_NEWEST_REVISION
	$DEBUG_MODE $HEADLINES_FILE $LINK_PREFIX $NEWS_ACCEPT_TIME
	$OUTPUT_FILE $STATUS_FILE $VERSION);
$LINK_PREFIX = 'http://pl.wikinews.org';

# Const: $VERSION
#   program version
$VERSION = '0.5.0';

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
$ADMIN_MAIL = 'der'.'beth.fora' . '@w'.'p.pl';

1;
