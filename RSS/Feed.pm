#!/usr/bin/perl
#
# Class: Feed
#   class for saving information as newsfeed (f.e. RSS)

package RSS::Feed;

use RSS::FeedEntry;
use RSS::Settings;

use Carp;
use Encode;

use strict;

####################################
# Group: Settings
####################################

# Const: $GENERATOR_NAME
#   string describing generator of the feed (can be empty)
my $GENERATOR_NAME = "Wikinews RSS bot by Derbeth ver. ".$RSS::Settings::VERSION;

####################################
# Group: Functions
####################################

# Constructor: new
#   just creates new feed object, nothing is saved
#
# Parameters:
#   $filename - path to file where feed should be saved
#   $title - title of the whole feed
#   $website - URL to website from which the feed is generated
#   $description - short description
#   $lang code - ISO code of feed language (by default 'pl')
#   $webmaster - information about feed maintainer (by default blank)
#   $pub_date - date when feed was first uploaded (by default blank)
#   $encoding - character encoding (by default 'utf-8')
sub new {
    my($classname,$filename,$title,$website,$description,
	$lang_code,$feed_link,$webmaster,$pub_date,$encoding) = @_;

    $lang_code = 'pl' unless $lang_code;
    $webmaster = '' unless defined($webmaster);
    $pub_date = '' unless defined($pub_date);
    $encoding = 'utf-8' unless defined($encoding);

    my $self = {};
    bless($self, $classname);
   
    $self->{'filename'} = $filename;
    $self->{'title'} = $title;
    $self->{'website'} = $website;
    $self->{'description'} = $description;
    $self->{'lang_code'} = $lang_code;
    $self->{'feed_link'} = $feed_link;
    $self->{'webmaster'} = $webmaster;
    $self->{'pub_date'} = $pub_date;
    $self->{'encoding'} = $encoding;
    
    $self->{'image_url'} = '';
    $self->{'image_title'} = '';
    $self->{'image_link'} = '';
    $self->{'image_width'} = '';
    $self->{'image_height'} = '';
    $self->{'copyright'} = '';
    
    $self->{'entries'} = [];
   
    return $self;
}

# Function: setImage
#   sets feed icon, remember to use before saving the feed
#
# Parameters:
#   $url - URL to the image
#   $title - image alternative text
#   $link - URL where image points to
#   $width - image width
#   $height - image height
sub setImage {
	my($self,$url,$title,$link,$width,$height) = @_;
	
	$self->{'image_url'} = $url;
	$self->{'image_title'} = $title;
	$self->{'image_link'} = $link;
	$self->{'image_width'} = $width;
	$self->{'image_height'} = $height;
}

# Function: setCopyright
#   sets copyright information of the feed
#
# Parameters:
#   $copyright - copyright text
sub setCopyright {
	my($self,$copyright) = @_;
	
	$self->{'copyright'} = $copyright;
}
	
# Function: toString
#   returns string representing feed
#
# Important:
#   returns debug data
sub toString {
	return "Feed"; # TEMP
}

# Function: formatTime
#   returns time formatted properly
#
# Parameters:
#   $timestamp - timestamp (like the result of time() function)
#
# Return value:
#   string like 'Sun, 19 May 2002 15:21:36 GMT'
sub formatTime {
	my($self, $timestamp) = @_;
	unless( defined($timestamp) ) { confess "formatTime: must pass a parameter"; }
	my $retval;
	
	my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($timestamp);
	my $dayname = qw/Sun Mon Tue Wed Thu Fri Sat/[$wday];
	my $monthname = qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/[$mon];
	$year += 1900;
	
	$retval = sprintf("$dayname, %02d $monthname $year %02d:%02d:%02d %s",
	$mday,$hour,$min,$sec, 'GMT');
	return $retval;
}

# Function: addEntry
#   adds new entry
#
# Parameters:
#   $title - news title
#   $date - news date (timestamp)
#   $link - URL to website with news
#   $summary - summary text
#   $guid - GUID of the news item (optional)
#
# Remarks:
#   if there are already <$RSS::Settings::MAX_ENTRIES>, oldest one is deleted to make place for
#   new
sub addEntry {
	my($self,$title,$date,$link,$summary,$guid) = @_;
	
	#if( $#{$self->{'entries'}} > $MAX_ENTRIES ) { return 0; } # don't add
	if( $#{$self->{'entries'}} >= $RSS::Settings::MAX_ENTRIES ) {
		shift @{$self->{'entries'}}; # remove oldest
	}
	
	# oldest entries first
	push @{$self->{'entries'}}, $self->_createEntry($title,$date,$link,$summary,$guid);
	
	#print "add entry $title - $link - $date\n" #DEBUG;
}

sub replaceEntry {
	my($self,$title,$date,$link,$summary,$guid) = @_;
	for(my $i=0; $i<=$#{$self->{'entries'}}; ++$i)
	{
		if( $self->{'entries'}[$i]->{'title'} eq $title )
		{ # replacing
			$self->{'entries'}[$i] = $self->_createEntry($title,$date,$link,$summary,$guid);
			return 1;
		}
	}
	return 0;
}

# Function: _createEntry
#   creates a new, properly formatted FeedEntry
#
# Parameters:
#   $title - news title
#   $date - news date (timestamp)
#   $link - URL to website with news
#   $summary - summary text
#   $guid - GUID of the news item (optional)
#
sub _createEntry {
	my($self,$title,$date,$link,$summary,$guid) = @_;
	$date = $self->formatTime($date);
	new RSS::FeedEntry($title,$date,$link,$summary,$guid);
}

sub removeEntry {
	my ($self, $entry_title) = @_;
	
	for(my $i=0; $i<=$#{$self->{'entries'}}; ++$i)
	{
		if( $self->{'entries'}[$i]->{'title'} eq $entry_title )
		{ # deleting
			for(my $j=$i; $j<$#{$self->{'entries'}}; ++$j)
			{
				$self->{'entries'}[$j] = $self->{'entries'}[$j+1];
			}
			--$#{$self->{'entries'}};
			return 1;
		}
	}
	return 0;
}

# Function: getHeading
#   internal function returning heading of the feed (part not dependant on items)
sub getHeading {
	my $self = pop @_;
	my $retval;
	
	$retval .= "<?xml version=\"1.0\" encoding=\"$self->{'encoding'}\"?>\n";
	$retval .= "<rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\">\n";
	$retval .= "<channel>\n";
	$retval .= "<language>$self->{'lang_code'}</language>\n";
	$retval .= "<title>$self->{'title'}</title>\n";
	$retval .= "<link>$self->{'website'}</link>\n";
	$retval .= "<description>$self->{'description'}</description>\n";
	$retval .= "<atom:link href=\"$self->{'feed_link'}\" rel=\"self\" type=\"application/rss+xml\" />\n" if $self->{'feed_link'};
	$retval .= "<webMaster>$self->{'webmaster'}</webMaster>\n" if $self->{'webmaster'};
	
	$retval .= "<pubDate>$self->{'pub_date'}</pubDate>\n" if $self->{'pub_date'};
	$retval .= "<lastBuildDate>".$self->formatTime(time())."</lastBuildDate>\n";
	
	if($self->{'image_url'} ne '' && $self->{'image_title'} ne '' && $self->{'image_link'} ne '')
	{
		$retval .= "<image>\n  <url>$self->{'image_url'}</url>\n";
		$retval .= "  <title>$self->{'image_title'}</title>\n";
		$retval .= "  <link>$self->{'image_link'}</link>\n";
		$retval .= "  <width>$self->{'image_width'}</width>\n" if $self->{'image_width'};
		$retval .= "  <height>$self->{'image_height'}</height>\n" if $self->{'image_height'};
		$retval .= "</image>\n";
	}
	$retval .= "<docs>http://backend.userland.com/rss/</docs>\n";
	$retval .= "<generator>$GENERATOR_NAME</generator>\n" if $GENERATOR_NAME;
	$retval .= "<copyright>$self->{'copyright'}</copyright>\n" if $self->{'copyright'};
	
	return $retval;
}
    

# Function: save
#   saves feed to file
sub save {
	my $self = pop @_;
	
	open(FEED_FILE,"> $self->{'filename'}") or die "cannot open file $self->{'filename'} to save feed";
	print FEED_FILE encode_utf8($self->getHeading());
	
	my $i;
	for($i= $#{$self->{'entries'}}; $i>=0; --$i) {  # start from end - latest first
	    print FEED_FILE encode_utf8($self->{'entries'}[$i]->toXML());
	}

   print FEED_FILE "</channel>\n";
   print FEED_FILE "</rss>\n";

	close FEED_FILE;

	
	my $now = localtime();
	print "-> feed $self->{filename} (", scalar(@{$self->{'entries'}}), " items) saved - $now\n";
	
	# nothing now
}

1;
