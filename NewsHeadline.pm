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
my @VULGARISMS = ('chuj', 'kutas', 'cipa', 'kurwa', 'kurwy', 'żydy', 'gówno',
	'jeban', 'jebać', 'pierdol', 'pierdal', 'pedał',
	'!!!!', 'wheeee',
	'shit', 'fuck', 'cock', 'nigger', 'queer', 'bitch');

############################################################################
# Group: Functions
############################################################################

# Constructor: new
#   creates new news headline and sets its time to current time
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

	#if( ! defined $title || ! defined $link ) { die "two parameters expected"; }
	if( ! defined $time ) { $time = time; }

	my $self = {};
   bless($self, "NewsHeadline");

   $self->{'title'} = $title;
   $self->{'link'} = $link;
   $self->{'time'} = $time;
   $self->{'summary'} = '';
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

# returns date in format like "Mon, 12 Dec 2005 12:45 CET"
sub getDate {
	my $self = pop @_;

	if (! $self->{'date_read'}) {
		my $order = $Settings::DATE_FROM_NEWEST_REVISION ? 'older' : 'newer';
		my $url = $Settings::LINK_PREFIX."/w/api.php?action=query&format=yaml&prop=revisions&rvprop=timestamp&rvdir=$order&rvlimit=1&titles=".uri_escape_utf8($self->{'title'});
		my $json = Derbeth::Web::strona_z_sieci($url);
		if ($json =~ m!"timestamp" *: *"([^"]+)"!) {
			my $timestamp = $1;
			if ($timestamp =~ /^(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)Z$/) {
				my $month = $2 - 1;
				# we use timegm() instead of timelocal() because dates from
				# JSON are in UTC (time zone is Z)
				$self->{'time'} = timegm($6,$5,$4,$3,$month,$1);
				if ($Settings::DEBUG_MODE) {
					print 'read time for ', encode_utf8($self->{'title'}), ': ',
						scalar(CORE::localtime($self->{'time'})), "\n";
				}
			} elsif ($Settings::DEBUG_MODE) {
				print "Cannot parse date: $timestamp\n";
			}
		} elsif ($Settings::DEBUG_MODE) {
			print "Wrong API response for $url: $json\n";
		}
		$self->{'date_read'} = 1;
	}
	return $self->{'time'};
}

# returns date in format like "Mon, 12 Dec 2005 12:45 CET"
sub getGuid {
	my $self = pop @_;

	if (! $self->{'guid_read'}) {
		my $url = $Settings::LINK_PREFIX."/w/api.php?action=query&format=yaml&prop=info&titles=".uri_escape_utf8($self->{'title'});
		my $json = Derbeth::Web::strona_z_sieci($url);
		if ($json =~ m!"pageid" *: *(\d+)!) {
			# generate GUI according to http://www.rssboard.org/rss-profile#element-channel-item-guid
			my $pageid = $1;
			my $domain = $Settings::DOMAIN;
			my $year = localtime->year() + 1900;
			$self->{'guid'} = "tag:$domain,$year:$pageid";
		} elsif ($Settings::DEBUG_MODE) {
			print "Wrong API response for $url: $json\n";
		}
		$self->{'guid_read'} = 1;
	}
	return $self->{'guid'};
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

# Function: getSummary
#  returns news summary, retrieves news summary from website if it hasn't been done
sub getSummary {
	my $self = pop @_;
	
	if( $self->{'summary'} eq '' ) { fetchSummary(); } # comment this on debug
	return $self->{'summary'};
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
