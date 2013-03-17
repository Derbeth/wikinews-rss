package RSS::CategoryReader;
use strict;
use utf8;

use parent 'RSS::NewsListReader';

use Derbeth::Web;
use URI::Escape;
use Unicode::Escape;
use Encode;

sub new {
	my ($class, $wiki_base, $source, $max_new_news) = @_;
	my $self = $class->SUPER::new(@_);
	$source = uri_escape_utf8($source);
	$self->{news_list_url} = $wiki_base."/w/api.php?action=query&format=yaml"
			. "&list=categorymembers&cmsort=timestamp&cmdir=desc&cmlimit=".$max_new_news
			."&cmtitle=Category:$source";
	return $self;
}

sub fetch_titles {
	my ($self) = @_;
	get_titles_from_yaml(Derbeth::Web::get_page($self->{'news_list_url'}));
}

sub get_titles_from_yaml {
	my ($text) = @_;
	my @titles;
	while ($text =~ /"title":"([^"}]+)"/gc) {
		push @titles, decode_utf8(Unicode::Escape::unescape($1));
	}
	return @titles;
}

1;
