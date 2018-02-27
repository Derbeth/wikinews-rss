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

use lib '.';
use RSS::NewsManager;
use RSS::ConfigurationReader;
use RSS::Settings;
use RSS::Status;
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
RSS::Settings::set_debug_mode() if $debug_mode;

$Derbeth::Web::user_agent = 'DerbethBot for Wikinews RSS';
$Derbeth::Web::max_files_in_cache=150;
$Derbeth::Web::debug=$RSS::Settings::DEBUG_MODE;
if ($RSS::Settings::DEBUG_MODE) {
	Derbeth::Web::enable_caching(1);
}

############################################################################
# Section: Functions
############################################################################


############################################################################
# Section: Main
############################################################################

# sets close event handler
$SIG{INT} = $SIG{TERM} = sub { RSS::Status::set_status(2); exit; };
# sets crash event handler
$SIG{__DIE__} = sub { print @_; RSS::Status::set_status(3); exit; };

RSS::Status::set_status(0); # started

print "rss-updater version $RSS::Settings::VERSION running.\n";
print "News are accepted after being present for at least $RSS::Settings::NEWS_ACCEPT_TIME minutes\n";

my $conf_reader = new RSS::ConfigurationReader();
my $vulgarism_detector = $conf_reader->create_vulgarism_detector('vulgarisms.yml');
my @feed_defs = $conf_reader->read_feeds('sources.yml');
my @news_managers;

foreach my $feed_def (@feed_defs) {
	my $feed = $feed_def->{'feed'};
	my $news_source = $feed_def->{'news_source'};
	print encode_utf8("Feed from $news_source->{wiki_base}=>$news_source->{source} read every $news_source->{check_mins} mins to $feed->{filename}\n");
	push @news_managers, new RSS::NewsManager($feed, $news_source, $feed_def->{'news_resolver'}, $vulgarism_detector);
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

 ISC license, see LICENCE

=head1 AUTHOR

 Derbeth, <https://github.com/Derbeth>, <derbeth@interia.pl>,
 <http://pl.wikinews.org/wiki/User:Derbeth>

=cut
