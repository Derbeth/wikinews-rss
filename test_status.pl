#!/usr/bin/perl

use strict;

use Status;

unlink($Settings::STATUS_FILE) if (-e $Settings::STATUS_FILE);
print "Testing bot started...\n";
set_status(0);
die unless(-e $Settings::STATUS_FILE);
print "\tOk, status file created\n";
print "Testing bot died...\n";
my $res = set_status(3);
die "Cannot send mail" unless ($res);
print "\tOk, mail sent on die\n";
print "Success!\n";
