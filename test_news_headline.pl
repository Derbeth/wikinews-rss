#!/usr/bin/perl -w

use strict;
use Test::Assert ':all';

use NewsHeadline;

sub test_vulgar {
	print "test_vulgar\n";
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

	print "\tPassed ", scalar(@testdata), " checks\n";
}

sub test_parseInfoResponse {
	my $news = new NewsHeadline('foo','link');
	open(IN,'testdata/info_response.json') or die;
	my @lines = <IN>;
	my $response = join('',@lines);
	close(IN);
	
	$news->parseInfoResponse($response);
	assert_num_equals(199643, $news->{'lastrevid'});
	assert_equals('tag:pl.wikinews.org,2013:44953', $news->{'guid'});
	print "Passed test_parseInfoResponse\n";
}

sub test_parseRevisionsResponse {
	my $news = new NewsHeadline('foo','link');
	open(IN,'testdata/rev_response.json') or die;
	my @lines = <IN>;
	my $response = join('',@lines);
	close(IN);
	
	$news->parseRevisionsResponse($response);
	assert_num_not_equals(time(), $news->{'time'});
	assert_num_not_equals(0, $news->{'time'});
	print "Pased test_parseRevisionsResponse\n";
}

test_vulgar();
test_parseInfoResponse();
test_parseRevisionsResponse();
print "Success!\n";
