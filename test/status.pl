#!/usr/bin/perl

use strict;

use Settings;
use Status;

my $tmp_status_file = "/tmp/wikinews-rss-status";
unlink($tmp_status_file) if (-e $tmp_status_file);
$Settings::STATUS_FILE = $tmp_status_file;
print "Testing bot started...\n";
set_status(0);
die unless(-e $tmp_status_file);
print "\tOk, status file created\n";
print "Testing bot died...\n";
my $res = set_status(3);
print "Success!\n";
unlink($tmp_status_file) if (-e $tmp_status_file);
