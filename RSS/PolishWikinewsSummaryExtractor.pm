package RSS::PolishWikinewsSummaryExtractor;
use strict;
use English;

use RSS::Settings;

sub new {
	my ($class, $link_prefix) = @_;

	my $self = {};
	bless($self, $class);

	$self->{link_prefix} = $link_prefix || die "required: link_prefix";

	return $self;
}

# Function: fixUrl
#   changes relative url to absolute one
sub fixUrl {
	my ($self,$url) = @_;
	return $url if ($url =~ /^http/);
	return "http:$url" if ($url =~ m!^//!);
	return $self->{link_prefix}.$url;
}

# Function: fixUrls
#   changes all relative URLs to absolute ones
sub fixUrls {
	my ($self,$text) = @_;
	my $retval = '';

	while( $text =~ /href="([^h].+?)"/s ) { # not a href="http://
		$retval .= $`.'href="'.$self->fixUrl($1).'"'; # prematch
		$text = $'; # postmatch
	}

	return $retval.$text;
}

sub extract {
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
			$summary = $self->fixUrls($summary);

			if( length $summary > $RSS::Settings::MAX_SUMMARY_LEN ) { # cutting off if too long
				my $cut;
				$summary = substr($summary,0,$RSS::Settings::MAX_SUMMARY_LEN);
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

1;
