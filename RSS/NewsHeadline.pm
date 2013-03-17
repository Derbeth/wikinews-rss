# Class: NewsHeadline
#   represents news headline: title, link and time
package RSS::NewsHeadline;

use RSS::Settings;
use Derbeth::MediaWikiApi;

use strict;

use Time::Local;
use Time::localtime;
use URI::Escape qw/uri_escape_utf8/;
use Encode;

############################################################################
# Group: Settings 
############################################################################

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
push @VULGARISMS, 'Ten artykuł jest właśnie', 'Strona do natychmiastowego skasowania'; # {{Tworzone}}, {{Ek}}

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
   $self->{'api_base_url'} = $source->{wiki_base}."/w/api.php?action=query&format=yaml&titles=".uri_escape_utf8($self->{'title'});
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

	$self->{'fetch_error'} = 0;

	my $info_url = $self->{'api_base_url'} . "&prop=info&inprop=url";
	my $order = $RSS::Settings::DATE_FROM_NEWEST_REVISION ? 'older' : 'newer';
	my $revisions_url = $self->{'api_base_url'} . "&prop=revisions&rvprop=timestamp&rvdir=$order&rvlimit=1";

	my $info_json = $self->queryApi($info_url);
	my $revisions_json = $self->queryApi($revisions_url);

	$self->parseInfoResponse($info_json);
	$self->parseRevisionsResponse($revisions_json);

	$self->fetchSummary() if !$self->{'fetch_error'};

	return !$self->{'fetch_error'};
}

sub queryApi {
	my ($self, $url) = @_;

	my $response = Derbeth::Web::get_page($url);
	if ($response !~ /"query"/) {
		print "Wrong API response for $url: $response\n" if $RSS::Settings::DEBUG_MODE;
		return '';
	}
	return $response;
}

sub parseInfoResponse {
	my ($self, $json) = @_;
	# TODO handle 'missing' param
	if ($json =~ m!"pageid" *: *(\d+)!) {
		# generate GUI according to http://www.rssboard.org/rss-profile#element-channel-item-guid
		my $pageid = $1;
		my $domain = $self->{source}->{domain};
		my $year = localtime->year() + 1900;
		$self->{'guid'} = "tag:$domain,$year:$pageid";
	} else {
		$self->{'fetch_error'} = 1;
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
	my $self = pop @_;
	
	foreach my $vulgarism (@VULGARISMS)
	{
		if( $self->{'summary'} =~ /$vulgarism/si || $self->{'title'} =~ /$vulgarism/si )
		{
			return $vulgarism;
		}
	}
	return 0;
}	
	

1;
