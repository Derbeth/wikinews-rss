# Class: NewsHeadline
#   represents news headline: title, link and time
package RSS::NewsHeadline;

use RSS::Settings;

use strict;

use Time::Local;
use Time::localtime;
use Encode;

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
   my ($classname,$source,$title,$link,$time) = @_;

   my $self = {};
   bless($self, $classname);

   $self->{'title'} = $title || die "expected news title!";
   $self->{'link'} = $link;
   $self->{'time'} = $time || time();
   $self->{'summary'} = '';

   $self->{'source'} = $source;

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

sub parse_info_response {
	my ($self, $info_hash) = @_;
	if ($info_hash->{missing} || $info_hash->{invalid}) {
		$self->{fetch_error} = 1;
		return;
	}
	my $pageid = $info_hash->{pageid};
	if (!$pageid || $pageid == -1) {
		$self->{fetch_error} = 1;
		return;
	}
	# generate GUID according to http://www.rssboard.org/rss-profile#element-channel-item-guid
	my $domain = $self->{source}->{domain};
	my $year = $self->{test_year} || localtime->year() + 1900;
	$self->{guid} = "tag:$domain,$year:$pageid";

	$self->{lastrevid} = $info_hash->{lastrevid};
	$self->{link} = $info_hash->{fullurl};
}

sub needs_refresh {
	my ($self, $info_hash) = @_;
	my $new_lastrevid = $info_hash->{lastrevid};
	if (!$self->{lastrevid} || $self->{lastrevid} < $new_lastrevid) {
		$self->{lastrevid} = $new_lastrevid;
		return 1;
	}
	return 0;
}

sub parse_revisions_response {
	my ($self, $revisions_hash) = @_;
	unless ($revisions_hash && $revisions_hash->{revisions}) {
		$self->{fetch_error} = 1;
		return;
	}
	my @revisions = @{$revisions_hash->{revisions}};
	if (@revisions) {
		my $timestamp = $revisions[0]->{timestamp};
		my $parsed = $self->timestampToTime($timestamp);
		if ($parsed) {
			$self->{'time'} = $parsed;
			if ($RSS::Settings::DEBUG_MODE) {
				print 'read time for ', encode_utf8($self->{'title'}), ': ',
					scalar(CORE::localtime($self->{'time'})), "\n";
			}
		} elsif ($RSS::Settings::DEBUG_MODE) {
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

sub process_page_text {
	my ($self, $page_text) = @_;

	my $summary = $self->{source}->{summary_extractor}->extract($page_text);
	if ($summary) {
		$self->{'summary'} = $summary;
	} else { # error
		print "Could not find paragraph in page content of ", encode_utf8($self->{'title'}), "\n";
		$self->{'summary'} = $self->{'title'};
	}
	return 1;
}

# Function: wasCensored
#   returns 1 if news summary or title contain spam or vulgarisms
sub wasCensored {
	my ($self, $vulgarism_detector) = @_;
	return $vulgarism_detector->detect($self->{summary})
		|| $vulgarism_detector->detect($self->{title});
}

1;
