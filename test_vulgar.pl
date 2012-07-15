#!/usr/bin/perl
use NewsHeadline;
use Derbeth::Wikipedia;
use Derbeth::Web;

use strict;
use utf8;

$Derbeth::Web::cache_on = 1;

my @testdata = (
'Fucking queers fuck off!|Test',
'Title|Fuck off',
'Title|Jebane to wszystko',
'Title|Ho ho!!!!!!!!',
'Wydupczy|La la la',
);

foreach my $t (@testdata) {
	my ($title, $summary) = split /\|/, $t;
	my $news = new NewsHeadline($title,'link',time);
	$news->{'summary'} = $summary;
	die "should be censored: $t" unless $news->wasCensored();
}

print scalar(@testdata), " tests succeeded\n";
