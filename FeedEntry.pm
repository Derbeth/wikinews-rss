# Class: FeedEntry
#   represents single news in RSS feed
#
# Project:
#   rss-updater (see for license & other info)
#
# Author:
#   Derbeth, <http://derbeth.w.interia.pl/>, <derbeth@interia.pl>
#            [[n:pl:User:Derbeth]]
package FeedEntry;

# Constructor: new
#   simply fills feed data
#
# Parameters:
#   $title - title of the news
#   $date - date (timestamp)
#   $link - URL of the news
#   $summary - summary of the news
sub new {
    my($classname,$title,$date,$link,$summary) = @_;
    
    my $self = {};
    bless($self, "FeedEntry");
    
    $self->{'title'} = $title;
    $self->{'date'} = $date;
    $self->{'link'} = $link;
    $self->{'summary'} = $summary;
    
    return $self;
}

# Function: toXML
#   returns XML representation of news
#
# Parameters:
#   none
#
# Return value:
#   XML code from (and including) <item> to </item>
sub toXML {
    my $self = pop @_;
    my $retval = "<item>\n";
    
    $retval .= "  <title>$self->{'title'}</title>\n";
    $retval .= "  <link>$self->{'link'}</link>\n";
    $retval .= "  <pubDate>$self->{'date'}</pubDate>\n";
    $retval .= "  <description>$self->{'summary'}</description>\n";
    $retval .= "</item>\n";
    return $retval;
}

sub equals {
	my($self, $other) = @_;
	if( ! defined $other->{'title'} ) { die "FeedEntry::equals: wrong comparison"; } 
	return( $self->{'title'} eq $other->{'title'} );
}

1;
