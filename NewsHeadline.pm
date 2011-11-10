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

sub getDate {
	my $self = pop @_;
	
	#return "Mon, 12 Dec 2005 12:45 CET"; # TEMP TODO
	return $self->{'time'};
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
	#my $page = $self->{'summary'}; #DEBUG ONLY
	
	$page =~ s/<table.*?<\/table>//gs; # remove tables
	$page =~ s/ class="extiw"//g; # remove unneccessary CSS class
	if ($page =~ /200\d<\/b><br \/><\/p>/) {
		$page = $POSTMATCH;
	}

	if( $page =~ /<p>(.+?)<\/p>/si ) { # find first paragraph
		my $summary = $1;
		$page = $POSTMATCH;
		
		
		# $summary =~ /200\d<\/b><br \/>/si
		while( $summary =~ /^<b>(.*?)<\/b>/si || $summary =~ /^(&#160;)?(<br.*?>)/si
		|| $summary =~ /^<a name=.+?<\/a>/si || $summary =~ /^<script.+?<\/script>/si ) {
		# ignore part with date, newline, anchor or script
			if( $' eq '' ) { # look for next paragraph
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
		
		if( $summary eq '' ) { # on error set title as summary
			#die "error";
			$self->{'summary'} = $self->{'title'}; return $self->{'summary'};
		}
		
		$summary = fixUrls($summary);
		
		if( length $summary > $MAX_SUMMARY_LEN ) { # cutting off if too long
			my $cut;
			$summary = substr($summary,0,$MAX_SUMMARY_LEN);
			if( ($cut=rindex($summary, '<a href=')) > rindex($summary, '</a>') )
			{
				$summary = substr($summary, 0, $cut);
			}
		}
		$summary =~ s/</&lt;/g;  # quoting HTML tags
		$summary =~ s/>/&gt;/g;
		
		$self->{'summary'} = $summary;	

		
	} else { # error
		print "Could not find paragraph in page content\n"; #DEBUG
		print "missing: $self->{'title'}\n";
		$self->{'summary'} = $self->{'title'}; return $self->{'summary'};
	}
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
