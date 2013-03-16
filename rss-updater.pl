#!/usr/bin/perl -w
# Programming language:
#   Perl 5
#
# Documentation standard:
#   NaturalDocs, <http://www.naturaldocs.org/>
#
# Encoding:
#   UTF-8

use Encode;
use Getopt::Long;
use Pod::Usage;

use NewsManager;
use FeedDefinitionReader;
use Settings;
use Status;
use Derbeth::Web 0.5.0;

use strict;
use utf8;

############################################################################
# Group: Settings
#   Program settings
#
# See also:
#   - <NewsHeadline::$MAX_SUMMARY_LEN> and <NewsHeadline::@VULGARISMS>
#   - <NewsManager::$WAIT_TIME>, <NewsManager::$MAX_PENDING> and <NewsManager::$MAX_SAVED>
#   - <Feed::$MAX_ENTRIES>
############################################################################

my $show_help=0;
my $debug_mode=0;

GetOptions(
	'debug|d' => \$debug_mode,
	'help|h' => \$show_help,
) or pod2usage('-verbose'=>1,'-exitval'=>1);
pod2usage('-verbose'=>2,'-noperldoc'=>1) if ($show_help);
Settings::set_debug_mode() if $debug_mode;

$Derbeth::Web::user_agent = 'DerbethBot for Wikinews RSS';
$Derbeth::Web::max_files_in_cache=150;
$Derbeth::Web::debug=$Settings::DEBUG_MODE;
if ($Settings::DEBUG_MODE) {
	Derbeth::Web::enable_caching(1);
}

############################################################################
# Section: Functions
############################################################################


############################################################################
# Section: Main
############################################################################

# sets close event handler
$SIG{INT} = $SIG{TERM} = sub { Status::set_status(2); exit; };
# sets crash event handler
$SIG{__DIE__} = sub { print @_; Status::set_status(3); exit; };

Status::set_status(0); # started

print "rss-updater version $Settings::VERSION running.\n";
print "News are accepted after being present for at least $Settings::NEWS_ACCEPT_TIME minutes\n";

my @feed_defs = new FeedDefinitionReader('sources.yml')->read();
my @news_managers;

foreach my $feed_def (@feed_defs) {
	my $feed = $feed_def->{'feed'};
	my $news_source = $feed_def->{'news_source'};
	print encode_utf8("Feed from $news_source->{wiki_base}=>$news_source->{source} read every $news_source->{check_mins} mins to $feed->{filename}\n");
	push @news_managers, new NewsManager($feed, $news_source);
}
print "Hit Control+C to exit.\n\n";

sleep 5;
while( 1 ) {
	foreach my $news_manager (@news_managers) { $news_manager->tick(); }
	sleep(60);
}


=head1 NAME

rss-updater.pl - updates Wikinews RSS channel

=head1 SYNOPSIS

 ./rss-updater.pl <options>

 Options:
   -d --debug             runs program in diagnostic mode

   -h --help              display help and exit

 All options are optional. All boolean options are can be negated using --no- prefix.

=head1 LICENCE

 3-clause BSD, <http://www.opensource.org/licenses/bsd-license.php>


=head1 AUTHOR

 Derbeth, <http://derbeth.w.interia.pl/>, <derbeth@interia.pl>,
 [[n:pl:User:Derbeth]]

=cut
