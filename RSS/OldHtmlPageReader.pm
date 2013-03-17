package RSS::OldHtmlPageReader;
use strict;
use utf8;

use parent 'RSS::BaseHtmlPageReader';

use Derbeth::Web;
use Derbeth::Wikipedia;
use URI::Escape;

sub new {
	my ($class, $wiki_base, $source, $max_new_news) = @_;
	my $self = $class->SUPER::new($max_new_news);
	$source = uri_escape_utf8($source);
	$self->{wiki_base} = $wiki_base || die "required: wiki_base";
	$self->{news_list_url} = $wiki_base."/w/index.php?title=".$source;
	return $self;
}

sub fetch_as_html_page {
	my($self) = @_;
	return cutoff($self->get_from_web());
}

sub get_from_web {
	my ($self) = @_;
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

	if( $error_msg ) {
		$self->report_fetch_failure($error_msg);
		return '';
	}

	Derbeth::Web::save_page_to_file($page, $RSS::Settings::HEADLINES_FILE);
	return $page;
}

sub cutoff {
	my ($content) = @_;
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
	return $content;
}

1;
