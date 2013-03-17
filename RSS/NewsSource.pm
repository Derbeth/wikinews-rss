package RSS::NewsSource;
use strict 'vars';
use utf8;

use RSS::PolishWikinewsSummaryExtractor;
use RSS::CategoryReader;
use RSS::OldHtmlPageReader;
use RSS::ApiHtmlPageReader;
use RSS::Status;
use Derbeth::Web 0.5.0;
use Derbeth::Wikipedia;

use Encode;

# my $HTML_PAGE_READER_IMPL = 'RSS::OldHtmlPageReader';
my $HTML_PAGE_READER_IMPL = 'RSS::ApiHtmlPageReader';

# Parameters:
#   $wiki_base - like 'http://pl.wikinews.org'
#   $source - like 'Szablon:Najnowszewiadomości'
#   $source_type - 'CATEGORY' or 'HTML'
sub new {
	my ($class, $check_interval_mins, $wiki_base, $domain, $source, $source_type, $max_new_news) = @_;

	my $self = {};
	bless($self, $class);

	$self->{'wiki_base'} = $wiki_base || die "missing wiki_base";
	$self->{'domain'} = $domain || die "missing domain";
	$self->{'source'} = $source || die "missing source";
	
	$self->{'summary_extractor'} = new RSS::PolishWikinewsSummaryExtractor($self->{'wiki_base'});

	if ($source_type eq 'CATEGORY') {
		$self->{'news_list_reader'} = new RSS::CategoryReader($wiki_base, $source, $max_new_news);
	} else { # HTML
		$self->{'news_list_reader'} = new $HTML_PAGE_READER_IMPL($wiki_base, $source, $max_new_news);
	}

	$self->{'ticks'} = 0;
	$self->{'check_mins'} = $check_interval_mins;

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

	my @titles = $self->{'news_list_reader'}->fetch_titles();
	$self->{'news_list_reader'}->clear_errors();

	if ($RSS::Settings::DEBUG_MODE) {
		print STDERR "Fetched ", scalar(@titles), " news from ", encode_utf8($self->{source}), ": ", brief_titles_list(@titles), "\n";
	}

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

1;
