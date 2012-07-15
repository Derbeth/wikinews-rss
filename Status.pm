package Status;

require Exporter;

use utf8;
use strict;

use Settings;

our @ISA = qw/Exporter/;
our @EXPORT = qw/set_status/;

# Function: set_status
#   set status: running or failure, saves it to a HTML file
#
# Parameters:
#   $running - see below
#   $last_saved - date when the news list was saved for the last time (optional)
#
# Status:
#   0 - started
#   1 - running
#   2 - stopped (closed)
#   3 - dead (on error)
sub set_status {
	my ($running, $last_saved) = @_;
	
	my $desc;
	
	unless( open(STATUS, "> $Settings::STATUS_FILE") ) {
		print "cannot open status file for writing: $!\n";
		return;
	}
	print STATUS <<HTML;
<!DOCTYPE html>
<html lang="en">
<head>
<title>Wikinews RSS bot status</title>
<meta http-equiv="Cache-control" content="no-cache"/>
<meta name="Robots" content="none"/>
</head>
<body>
<p><strong>
HTML

	my $now = localtime();
	SWITCH: {
		if( $running == 0 )  {
			print STATUS 'STARTED'; $desc = "Bot started on $now";
			last SWITCH;
		}
		if( $running == 1 )  {
			print STATUS 'RUNNING';
			$desc = "Bot running. News last checked on $now, " .
				($last_saved ? "last saved on $last_saved" : "not saved so far");
			last SWITCH;
		}
		if( $running == 2 ) {
			print  STATUS 'STOPPED'; $desc = "Bot was stopped or system was closed on $now";
			last SWITCH;
		}
		print STATUS 'DEAD'; $desc = "Bot terminated because of an error on $now";
	}
	
	print STATUS "</strong></p><p>$desc</p>";
	print STATUS '</body></html>';

	close STATUS;
	
	if( $running == 3 ) { notify_admin(); }
}

# Function: notify_admin
#   sends and e-mail notifying administrator of bot crash
sub notify_admin {
	open(MAIL, "|/usr/lib/sendmail -t");

	print MAIL "To: $Settings::ADMIN_MAIL\n";
	print MAIL "From: $ENV{USER}\n";
	print MAIL "Subject: RSS bot dead\n";

	print MAIL "Wikinews RSS bot is dead.\n";

	close (MAIL);
}

1;
