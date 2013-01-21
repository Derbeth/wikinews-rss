#!/usr/bin/perl

package DebugSettings;

use strict;

use Settings;

$Settings::PURGE_NEWS_LIST = 0;
$Settings::CHECKOUT_PAUSE = 1;
$Settings::NEWS_ACCEPT_TIME = 1;

# $Settings::DEBUG_MODE = 1;
# $Settings::READ_LIST_FROM_FILE = 1;

print "Debug settings used\n";

1;
