#!/usr/bin/perl -w

use strict;
use Test::Assert ':all';

use lib '.';
use RSS::NewsHeadline;
use RSS::NewsResolver;
use RSS::ConfigurationReader;
use Derbeth::Web;
use Derbeth::MediaWikiApi;

my $test_in = 'test/data/';

sub test_vulgar {
	print "test_vulgar\n";
	my $vulgarism_detector = new RSS::ConfigurationReader()->create_vulgarism_detector('vulgarisms.yml');
	my @testdata = (
	'Fucking queers fuck off!|Safe content',
	'Safe title|Fuck off',
	'Safe title|Jebane to wszystko',
	'Safe title|Question marks!!!!!!',
	'Wydupczy|Safe content',
	);

	foreach my $t (@testdata) {
		my ($title, $summary) = split /\|/, $t;
		my $news = new RSS::NewsHeadline({wiki_base=>'foo'}, $title);
		$news->{'summary'} = $summary;
		die "should be censored: '$t'" unless $news->wasCensored($vulgarism_detector);
	}

	print "\tPassed ", scalar(@testdata), " checks\n";
}

sub test_parse_info_response {
	my $news = new RSS::NewsHeadline({wiki_base=>'foo',domain=>'pl.wikinews.org'},'foo','link');
	$news->{test_year} = 2013;
	my $in_file = "$test_in/info_response.json";
	my $parsed_yaml = Derbeth::MediaWikiApi::parse_yaml(Derbeth::Web::get_page_from_file($in_file)) || die "cannot read $in_file";
	my $info_hash = RSS::NewsResolver::get_single_page_hash($parsed_yaml);
	
	$news->parse_info_response($info_hash);
	assert_false($news->{'fetch_error'});
	assert_num_equals(199643, $news->{'lastrevid'});
	assert_equals('tag:pl.wikinews.org,2013:44953', $news->{'guid'});
	assert_equals('http://pl.wikinews.org/wiki/220._rocznica_%C5%9Bmierci_Ludwika_XVI', $news->{'link'});
	print "Passed test_parse_info_response\n";
}

sub test_parse_revisions_response {
	my $news = new RSS::NewsHeadline({wiki_base=>'foo'},'foo','link');
	my $in_file = "$test_in/rev_response.json";
	my $parsed_yaml = Derbeth::MediaWikiApi::parse_yaml(Derbeth::Web::get_page_from_file($in_file)) || die "cannot read $in_file";
	my $revisions_hash = RSS::NewsResolver::get_single_page_hash($parsed_yaml);
	
	$news->parse_revisions_response($revisions_hash);
	assert_num_not_equals(time(), $news->{'time'});
	assert_num_not_equals(0, $news->{'time'});
	print "Pased test_parse_revisions_response\n";
}

test_vulgar();
test_parse_info_response();
test_parse_revisions_response();
print "Success!\n";
