#!/usr/bin/perl
use NewsHeadline;
use Derbeth::Wikipedia;
use Derbeth::Web;

use strict 'vars';

$Derbeth::Web::cache_on = 1;

my $news = new NewsHeadline('tit','link',time);

#open(FILE,"wampiriada.htm") or die "nie otwarlem pliku";

#my $retval;
#my $c = <FILE>;
#while($c) { $retval .= $c; $c=<FILE>; }

#$retval = Derbeth::Wikipedia::wydziel_zawartosc($retval);

$news->{'link'} =
'http://pl.wikinews.org/wiki/Warszawa:_Gesty_papieża_wobec_wiernych';

$news->fetchSummary();
print $news->getSummary();

