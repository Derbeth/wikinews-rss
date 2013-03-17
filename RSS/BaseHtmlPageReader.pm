package RSS::BaseHtmlPageReader;
use strict;
use utf8;

use parent 'RSS::NewsListReader';

sub new {
	my ($class, $max_new_news) = @_;
	my $self = $class->SUPER::new();
	$self->{max_new_news} = $max_new_news || die "required: max_new_news";
	return $self;
}

sub fetch_titles {
	my ($self) = @_;
	$self->get_titles_from_html($self->fetch_as_html_page());
}

# Function: fetch_as_html_page
#   gets list of latest news from server
#
# Parameters:
#   none
#
# Returns:
#   string with content of HTML file
#
# Remarks:
#   function counts number of cases where news list cannot be fetched from
#   server. If it exceeds <$MAX_FETCH_FAILURES>, script dies.
sub fetch_as_html_page {
	die "unimplemented";
}

# Function: get_titles_from_html
#   retrieves news headlines from news list
#
# Parameters:
#   $bare_list - HTML file with list of news
#
# Returns:
#   list of <NewsHeadline> objects
#
# Remarks:
#   reads only first <$self->{max_new_news}> links
sub get_titles_from_html {
	my ($self,$content) = @_;

	my $count = 0;
	my @titles;

	while( 1 ) {
		if( $content =~ /<a href=(.+?)<\/a>/ )
		{
			$content = $'; # POSTMATCH

			my $whole_link = $1;
			if( $whole_link =~ /^"([^">]+)"[^>]*>(.*)/ && $whole_link !~ /class="new"/)
			{
				my($m1,$m2)=($1,$2);
				push @titles, $m2;
				if( ++$count >= $self->{'max_new_news'} ) { last; } # end after adding $self->{'max_new_news'} news
			}
		} else {
			last;
		}
	}

	return @titles;
}

1;
