package NewsSource;
use strict 'vars';

use Status;
use Derbeth::Web 0.5.0;
use Derbeth::Wikipedia;

use Encode;

# Const: $MAX_FETCH_FAILURES
#   how many fetch failures can be tollerated
my $MAX_FETCH_FAILURES = 20;

# Const: $ERROR_CLEAR_DELAY
#   after n main loops error count will be decreased by one
#   As result, every ($CHECKOUT_PAUSE * $ERROR_CLEAR_DELAY) minutes error number
#   will be reduced by one
#
#   Should be greater than $MAX_FETCH_FAILURES
my $ERROR_CLEAR_DELAY=20;

sub new {
	my ($class, $news_list_url) = @_;

	my $self = {};
	bless($self, "NewsSource");

	$self->{'news_list_url'} = $news_list_url;

	# internal variable, counts fetch failures for <fetch_news_list()>
	$self->{'fetch_failures'} = 0;
	$self->{'loop_count'}=1;

	return $self;
}

sub fetch_titles {
	my ($self) = @_;

	my @titles = retrieve_news_headlines($self->fetch_news_list());

	$self->clear_errors();

	return @titles;
}

# Function: fetch_news_list
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
sub fetch_news_list {
	my($self) = @_;
	if ($Settings::READ_LIST_FROM_FILE) {
		my $input_file = $Settings::HEADLINES_FILE;
		print "Reading new list from file $input_file\n";
		open(FILE,$input_file) or die "cannot read news list: $!";
		my @lines = <FILE>;
		close(FILE);
		my $content = join('', @lines);
		return decode_utf8($content);
	}
	my $error_msg = '';

	Derbeth::Web::purge_page($self->{'news_list_url'}) if $Settings::PURGE_NEWS_LIST;
	my $page = decode_utf8(Derbeth::Wikipedia::get_page($self->{'news_list_url'}));

	if( $page eq '' ) { $error_msg = "cannot fetch news list from server"; }
	if( Derbeth::Wikipedia::jest_redirectem($page) ) { $error_msg = "redirect instead of news list";}
	if(! Derbeth::Wikipedia::strona_istnieje($page) ) { $error_msg = "news list: page does not exist"; }

	if( $error_msg ne '' ) {
		my $now = localtime();
		print "$now:  $error_msg\n";
		if( ++$self->{fetch_failures} >= $MAX_FETCH_FAILURES ) {
			Status::set_status(2);
			die "too many errors ($self->{fetch_failures})";
		}
		return '';
	}

	open(OUT, ">$Settings::HEADLINES_FILE");
	print OUT encode_utf8($page);
	close(OUT);
	return $page;
}

# Function: retrieve_news_headlines
#   retrieves news headlines from news list
#
# Parameters:
#   $bare_list - HTML file with list of news
#
# Returns:
#   list of <NewsHeadline> objects
#
# Remarks:
#   reads only first <$MAX_NEW_NEWS> links
sub retrieve_news_headlines {
	my $content = pop @_;

	if( $content eq '' ) { return (); }
	if ($content =~ /<!-- *(bodytext|bodycontent|start content) *-->/) {
		$content = $';
	} else {
		print STDERR "WARN: cannot cut off begin\n";
	}
	if ($content =~ /<div class="printfooter">/) {
		$content = $`;
	} else {
		print STDERR "WARN: cannot cut off end\n";
	}

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
				if( ++$count >= $Settings::MAX_NEW_NEWS ) { last; } # end after adding $MAX_NEW_NEWS news
			}
		} else {
			last;
		}
	}

	if ($Settings::DEBUG_MODE) {
		print STDERR "Fetched ", scalar(@titles), " news: ", join(' ', map {encode_utf8("`$_'")} @titles), "\n";
	}

	return @titles;
}

sub clear_errors
{
	my($self) = @_;
	$self->{loop_count}=($self->{loop_count}+1) % $ERROR_CLEAR_DELAY;
	if( $self->{loop_count} == 0 && $self->{fetch_failures} > 0 ) {
		--$self->{fetch_failures};
	}
}

1;
