package RSS::NewsSource;
use strict 'vars';
use utf8;

use RSS::Status;
use Derbeth::Web 0.5.0;
use Derbeth::Wikipedia;

use Encode;
use URI::Escape;
use Unicode::Escape;

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

# Parameters:
#   $wiki_base - like 'http://pl.wikinews.org'
#   $source - like 'Szablon:Najnowszewiadomości'
#   $source_type - 'CATEGORY' or 'HTML'
sub new {
	my ($class, $check_interval_mins, $wiki_base, $domain, $source, $source_type, $max_new_news) = @_;

	my $self = {};
	bless($self, $class);
	
	$self->{'source_type'} = $source_type || 'HTML';
	$self->{'wiki_base'} = $wiki_base || die "missing wiki_base";
	$self->{'domain'} = $domain || die "missing domain";
	$self->{'source'} = $source || die "missing source";
	$self->{'max_new_news'} = $max_new_news || die "missing max_new_news";

	$source = uri_escape_utf8($source);
	if ($self->{'source_type'} eq 'CATEGORY') {
		$self->{'news_list_url'} = $wiki_base."/w/api.php?action=query&format=yaml"
			. "&list=categorymembers&cmsort=timestamp&cmdir=desc&cmlimit=".$self->{'max_new_news'}
			."&cmtitle=Category:$source";
	} else { # HTML
		$self->{'news_list_url'} = $wiki_base."/w/index.php?title=".$source;
	}

	$self->{'ticks'} = 0;
	$self->{'check_mins'} = $check_interval_mins;

	# internal variable, counts fetch failures for <fetch_news_list()>
	$self->{'fetch_failures'} = 0;
	$self->{'loop_count'}=1;

	return $self;
}

sub tick {
	my ($self) = @_;
	my $should_fetch_now = ($self->{'ticks'} % $self->{'check_mins'} == 0);
	++$self->{'ticks'};
	return $should_fetch_now;
}

sub fetch_titles {
	my ($self) = @_;

	my @titles;
	if ($self->{'source_type'} eq 'CATEGORY') {
		@titles = get_titles_from_yaml(Derbeth::Web::get_page($self->{'news_list_url'}));
	} else {
		@titles = $self->get_titles_from_html($self->fetch_as_html_page());
	}

	if ($RSS::Settings::DEBUG_MODE) {
		print STDERR "Fetched ", scalar(@titles), " news from ", encode_utf8($self->{source}), ": ", brief_titles_list(@titles), "\n";
	}

	$self->clear_errors();

	return @titles;
}

sub brief_titles_list {
	my @titles = @_;
	@titles = map { crop_after(35, $_) } @titles;
	join(' ', map {encode_utf8("`$_'")} @titles);
}

sub crop_after {
	my ($max_len, $text) = @_;
	if (length($text) <= $max_len) {
		return $text;
	} else {
		return substr($text, 0, $max_len-1) . '…';
	}
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
	my($self) = @_;
	if ($RSS::Settings::READ_LIST_FROM_FILE) {
		my $input_file = $RSS::Settings::HEADLINES_FILE;
		print "Reading new list from file $input_file\n";
		return Derbeth::Web::get_page_from_file($input_file);
	}
	my $error_msg = '';

	Derbeth::Web::purge_page($self->{'news_list_url'}, $self->{'wiki_base'}) if $RSS::Settings::PURGE_NEWS_LIST;
	my $page = Derbeth::Web::get_page($self->{'news_list_url'});

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

	Derbeth::Web::save_page_to_file($page, $RSS::Settings::HEADLINES_FILE);
	return $page;
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
				if( ++$count >= $self->{'max_new_news'} ) { last; } # end after adding $self->{'max_new_news'} news
			}
		} else {
			last;
		}
	}

	return @titles;
}

sub get_titles_from_yaml {
	my ($text) = @_;
	my @titles;
	while ($text =~ /"title":"([^"}]+)"/gc) {
		push @titles, decode_utf8(Unicode::Escape::unescape($1));
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
