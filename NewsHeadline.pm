#!/usr/bin/perl
#
# Class: NewsHeadline
#   represents news headline: title, link and time
#
# Project:
#   rss-updater (see for license & other info)
#
# Author:
#   Derbeth, <http://derbeth.w.interia.pl/>, <derbeth@interia.pl>
#            [[n:pl:User:Derbeth]]

package NewsHeadline;

use Derbeth::Wikipedia;
use Settings;

use strict;
use English;

use Time::Local;
use Time::localtime;
use URI::Escape qw/uri_escape_utf8/;
use Encode;

############################################################################
# Group: Settings 
############################################################################

# Const: $MAX_SUMMARY_LEN
#   maximal length of summary text (in characters)
my $MAX_SUMMARY_LEN = 2000;

# Const: $VULGARISMS
#   Lists of offensive words. If any of these is found in news title or text,
#   it won't be added to RSS.
#
#   You can use regexp here.
my @VULGARISMS = qw@chuj kutas cipa kurwa kurwy żydy gówno
	dupczy cwel
	jeban jebać pierdol pierdal pedał
	!!!! wheeee
	shit fuck cock nigger queer bitch@;

############################################################################
# Group: Functions
############################################################################

# Constructor: new
#   creates new news headline and sets its time to current time.
#
#   By default a newly created news headline contains only title,
#   additional details (link, summary, date, guid) are filled when
#   <fetchDetails() is called.
#
# Parameters:
#   $title - title of news
#   $link  - URL link to news body
#   $time  - time (by default current time)
#
# Returns:
#   reference to new <NewsHeadline> object
sub new {
	my ($classname,$title,$link,$time) = @_;

	if( ! defined $title ) { die "expected news title!"; }
	if( ! defined $time ) { $time = time; }

	my $self = {};
   bless($self, "NewsHeadline");

   $self->{'title'} = $title;
   $self->{'link'} = $link;
   $self->{'time'} = $time;
   $self->{'summary'} = '';
   $self->{'api_base_url'} = $Settings::LINK_PREFIX."/w/api.php?action=query&format=yaml&titles=".uri_escape_utf8($self->{'title'});
   #printf("title: '%s' (%s)\n", $self->{'title'}, $title); DEBUG

   return $self;
}

# Function: getAgeMinutes
#
# Parameters:
#   none
#
# Returns:
#   news age - in minutes (int)
sub getAgeMinutes {
	my $self = pop(@_);
	
	my $time_diff = time() - $self->{'time'};
	return $time_diff / 60;
}

sub fetchDetails {
	my $self = pop @_;

	my $info_url = $self->{'api_base_url'} . "&prop=info&inprop=url";
	my $order = $Settings::DATE_FROM_NEWEST_REVISION ? 'older' : 'newer';
	my $revisions_url = $self->{'api_base_url'} . "&prop=revisions&rvprop=timestamp&rvdir=$order&rvlimit=1";

	my $info_json = $self->queryApi($info_url);
	my $revisions_json = $self->queryApi($revisions_url);

	$self->parseInfoResponse($info_json);
	$self->parseRevisionsResponse($revisions_json);

	$self->fetchSummary();
}

sub queryApi {
	my ($self, $url) = @_;

	my $response = Derbeth::Web::get_page($url);
	if ($response !~ /"query"/) {
		print "Wrong API response for $url: $response\n" if $Settings::DEBUG_MODE;
		return '';
	}
	return $response;
}

sub parseInfoResponse {
	my ($self, $json) = @_;
	if ($json =~ m!"pageid" *: *(\d+)!) {
		# generate GUI according to http://www.rssboard.org/rss-profile#element-channel-item-guid
		my $pageid = $1;
		my $domain = $Settings::DOMAIN;
		my $year = localtime->year() + 1900;
		$self->{'guid'} = "tag:$domain,$year:$pageid";
	}
	if ($json =~ m!"lastrevid" *: *(\d+)!) {
		$self->{'lastrevid'} = $1;
	}
	if ($json =~ m!"fullurl" *: *"([^"]+)"!) {
		my $link = $1;
		$link =~ s!\\/!/!g; # TODO replace with a proper YAML parsing
		$self->{'link'} = $link;
	}
}

sub parseRevisionsResponse {
	my ($self, $json) = @_;
	if ($json =~ m!"timestamp" *: *"([^"]+)"!) {
		my $timestamp = $1;
		my $parsed = $self->timestampToTime($timestamp);
		if ($parsed) {
			$self->{'time'} = $parsed;
			if ($Settings::DEBUG_MODE) {
				print 'read time for ', encode_utf8($self->{'title'}), ': ',
					scalar(CORE::localtime($self->{'time'})), "\n";
			}
		} elsif ($Settings::DEBUG_MODE) {
			print "Cannot parse date: $timestamp\n";
		}
	}
}

sub timestampToTime {
	my ($self, $timestamp) = @_;
	my $result = 0;
	if ($timestamp =~ /^(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)Z$/) {
		my $month = $2 - 1;
		# we use timegm() instead of timelocal() because dates from
		# JSON are in UTC (time zone is Z)
		$result = timegm($6,$5,$4,$3,$month,$1);
	}
	return $result;
}

sub refresh {
	my $self = pop @_;
	my $info_url = $self->{'api_base_url'} . "&prop=info";
	my $json = Derbeth::Web::get_page($info_url);
	if ($json =~ m!"lastrevid" *: *(\d+)!) {
		my $newLastRevId = $1;
		if (!$self->{'lastrevid'} || $self->{'lastrevid'} < $newLastRevId) {
			$self->{'lastrevid'} = $newLastRevId;
			$self->fetchSummary();
			return 1;
		}
	}
	return 0;
}

# Function: toString
#
# Parameters:
#   $short - if true, only title will be rendered
#
# Returns:
#   string representing news
sub toString {
	my ($self, $short) = @_;
	my $retval = $short
		? "'" . $self->{'title'} . "'"
		: sprintf('%s - %s - %i',$self->{'title'},$self->{'link'},$self->getAgeMinutes());
	return $retval;
}

sub equals {
	my($self, $other) = @_;
	if( ! defined $other->{'title'} ) { die "NewsHeadline::equals: wrong comparison"; }
	return( $self->{'title'} eq $other->{'title'} );
}

# Function: fixUrl
#   changes relative url to absolute one
sub fixUrl {
	my ($url) = @_;
	return $url if ($url =~ /^http/);
	return "http:$url" if ($url =~ m!^//!);
	return $Settings::LINK_PREFIX.$url;
}

# Function: fixUrls
#   changes all relative URLs to absolute ones
sub fixUrls {
	my ($text) = @_;
	my $retval = '';
	
	while( $text =~ /href="([^h].+?)"/s ) { # not a href="http://
		$retval .= $`.'href="'.fixUrl($1).'"'; # prematch
		$text = $'; # postmatch
	}	
	
	return $retval.$text;
}
	
# Function: fetchSummary
#   fetches news summary from website
sub fetchSummary {
	my $self = pop @_;
	
	my $page = Derbeth::Wikipedia::pobierz_zawartosc_strony($self->{'link'});

	my $summary = $self->extractSummary($page);
	if ($summary) {
		$self->{'summary'} = $summary;
	} else { # error
		print "Could not find paragraph in page content of ", encode_utf8($self->{'title'}), "\n";
		$self->{'summary'} = $self->{'title'};
		return $self->{'summary'};
	}
}

sub extractSummary {
	my ($self, $page) = @_;
	my $summary;
	$page =~ s/ {2,}/ /g;
	$page =~ s/<table.*?<\/table>//gs; # remove tables
	#$page =~ s/^.*<\/table>//s; # remove rest of the tables
	$page =~ s/ class="[^<>"]+"//g; # remove unneccessary CSS class
	if ($page =~ /200\d<\/b><br \/><\/p>/) {
		$page = $POSTMATCH;
	}

	if( $page =~ /<p>(.+?)<\/p>/si ) { # find first paragraph
		$summary = $1;
		$page = $POSTMATCH;
		
		
		while( $summary =~ /^(&#160;)?(<br.*?>)/si
		|| $summary =~ /^<a name=.+?<\/a>/si || $summary =~ /^<script.+?<\/script>/si
		|| $summary =~ /^<span id="coordinates"/ ) {
		# ignore part with date, newline, anchor or script
			if( $' eq '' || $& =~ /coordinates/) { # look for next paragraph
				if( $page =~ /<p>(.+?)<\/p>/si ) {
					$summary = $1;
					$page = $';
					if( $page =~ /^\s*<table.*?<\/table>/si )
					{
						$page = $';
					}

				} else {
					$summary = '';
				}
			} else {
				$summary = $';
			}
		}

		$summary =~ s/^\s*<b>(.*)<\/b>\s*$/$1/si;

		# remove notes
		$summary =~ s!<sup id="cite_ref[^>]+><a[^>]+>[^<>]+</a></sup>!!;

		if( $summary) {
			# remove link titles
			$summary =~ s/(<a[^<>]+)title="[^<>"]*"/$1/g;
			$summary =~ s/ >/>/g;
			$summary = fixUrls($summary);
			
			if( length $summary > $MAX_SUMMARY_LEN ) { # cutting off if too long
				my $cut;
				$summary = substr($summary,0,$MAX_SUMMARY_LEN);
				if( ($cut=rindex($summary, '<a href=')) > rindex($summary, '</a>') )
				{
					$summary = substr($summary, 0, $cut);
				}
			}
			$summary =~ s/&/&amp;/g;  # quoting HTML
			$summary =~ s/</&lt;/g;
			$summary =~ s/>/&gt;/g;

			$summary =~ s/^\s+|\s+$//s;
		}
	}
	return $summary;
}

# Function: wasCensored
#   returns 1 if news summary or title contain spam or vulgarisms
sub wasCensored {
	my $self = pop @_;
	
	foreach my $vulgarism (@VULGARISMS)
	{
		if( $self->{'summary'} =~ /$vulgarism/si || $self->{'title'} =~ /$vulgarism/si )
		{
			print "vulgarism '$vulgarism' found in news '$self->{title}'\n";
			return 1;
		}
	}
	return 0;
}	
	

1;
