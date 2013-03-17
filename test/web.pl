#!/usr/bin/perl -w

use strict;
use utf8;

use Derbeth::Web;

use File::Path qw(make_path remove_tree);
use Test::Assert ':all';
use Encode;

# === Running

test_get_page_encoding();

# === Tests

sub test_get_page_encoding {
	my $temp_cache_dir = '/tmp/derbeth-web-test-page-cache';
	my $page_url = 'http://pl.wikisource.org/w/index.php?title=Wikiskryba:Derbeth&action=raw';

	remove_tree $temp_cache_dir;
	make_path $temp_cache_dir;

	$Derbeth::Web::cache_dir = $temp_cache_dir;
	assert_equals($temp_cache_dir, $Derbeth::Web::cache_dir);
	$Derbeth::Web::cache_pages = 1;
	$Derbeth::Web::debug = 1;

	assert_equals(0, pages_in_dir($temp_cache_dir), "should start with no cached pages");

	my $fresh_page_text = Derbeth::Web::get_page($page_url);

	$fresh_page_text =~ /\w/ || die "empty page text: ".encode_utf8($fresh_page_text);
	index($fresh_page_text, 'Na Wikisource') != -1 || die "read wrong content: ".encode_utf8($fresh_page_text);
	index($fresh_page_text, 'więc') != -1 || die "did not read non-ASCII chars: ".encode_utf8($fresh_page_text);

	assert_equals(1, pages_in_dir($temp_cache_dir), "should add fresh page to cache");

	my $cached_page_text = Derbeth::Web::get_page($page_url);

	$cached_page_text =~ /\w/ || die "empty page text: ".encode_utf8($cached_page_text);;
	index($cached_page_text, 'Na Wikisource') != -1 || die "read wrong content: ".encode_utf8($cached_page_text);
	index($cached_page_text, 'więc') != -1 || die "did not read non-ASCII chars: ".encode_utf8($cached_page_text);
	assert_equals($fresh_page_text, $cached_page_text);

	assert_equals(1, pages_in_dir($temp_cache_dir), "should read page from cache and not add any new cached files");
	print "test_get_page_encoding: success!\n";
}

# ==== Helper functions

sub pages_in_dir {
	my ($dir) = @_;
	opendir(my $dh, $dir) || die "cannot open $dir: $!";
	my @contents = grep { !/^\./ } readdir($dh);
	closedir $dh;
	return scalar(@contents);
}
