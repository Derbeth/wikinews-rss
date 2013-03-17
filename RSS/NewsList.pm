# Class: NewsList
#   list of <NewsHeadline> objects
package RSS::NewsList;

use strict 'vars';

############################################################################
# Group: Settings 
############################################################################

# Const: $DEFAULT_SIZE
#   default size of list
my $DEFAULT_SIZE = 30;

############################################################################
# Group: Functions
############################################################################


# Function: new
#   creates new list of news
#
# Parameters:
#   $size - maximal size (optional, 30 by default)
sub new {
	my($classname,$size) = @_;
	$size = $DEFAULT_SIZE unless defined $size;
	
	my $self = {};
   bless($self, $classname);
   
   $self->{'news'} = [];
   $self->{'size'} = $size;
   
   return $self;
}

# Function: add
#   adds new news to list
#
# Parameters:
#   $news - object of class <NewsHeadline>
#
# Remarks:
#   if number of news equals maximum size, 
sub add {
	my ($self, $news) = @_;
	
	if( $self->contains($news) ) { return 0; }
	#if( $#{$self->{'news'}} > $self->{'size'} ) { return 0; } # too many elements - don't add
	if( $#{$self->{'news'}}+1 >= $self->{'size'} ) { 
		shift @{$self->{'news'}}; # remove oldest
	}
	
	push @{$self->{'news'}}, $news;
}

# Function: remove
#   removes news from this news list
#
# Parameters:
#   $news - removed <NewsHeadline>
#
# Returns:
#   1 - if news was deleted
#   0 - if not found
#
sub remove {
	my ($self, $news) = @_;
	if( ! defined $news ) { die "NewList::remove: expected news as a parameter"; }
	
	for(my $i=0; $i<=$#{$self->{'news'}}; ++$i)
	{
		if( $self->{'news'}[$i]->equals($news) )
		{ # deleting
			for(my $j=$i; $j<$#{$self->{'news'}}; ++$j)
			{
				$self->{'news'}[$j] = $self->{'news'}[$j+1];
			}
			--$#{$self->{'news'}};
			return 1;
		}
	}
	return 0;
}

# Function: contains
#
sub contains {
	my($self, $news) = @_;
	my $i;
	for($i=0; $i<=$#{$self->{'news'}}; ++$i)
	{
		if( $self->{'news'}[$i]->equals($news) )
		{
			
			return 1;
		}
	}
	return 0;
}
	

# Function: toString
#
sub toString {
	my ($self, $short) = @_;
	my $retval = "";
	
# 	$retval .= "size: " . ($#{$self->{'news'}}+1) . "\n"; # DEBUG
	my $i;
	for($i=0; $i<=$#{$self->{'news'}}; ++$i)
	{
		$retval .= $self->{'news'}[$i]->toString($short) . "\n";
	}
	return $retval;
}

# Function: removeOlderThan
#   removes news that are older than $age
sub removeOlderThan {
	my($self, $age) = @_;

	if( ! defined $age ) { die "NewList::removeOlderThan: expected age as a parameter"; }
	
	my $i;
	
	for($i=0; $i<=$#{$self->{'news'}}; )
	{
		if( $self->{'news'}[$i]->getAgeMinutes() > $age )
		{ # deleting
			my $elm = pop @{$self->{'news'}};
			if( $i <= $#{$self->{'news'}} )
			{
				$self->{'news'}[$i] = $elm;
			}
		} else {
			++$i;
		}
	}
}

# Function: reverseList
#   reverses list
sub reverseList {
	my $self = pop @_;
	
	@{$self->{'news'}} = reverse @{$self->{'news'}};
}

# Function: getAgeMinutes
#
sub getAgeMinutes {
	my($self, $news) = @_;
	if( ! defined $news ) { die "NewsList::getAgeMinutes: no parameter"; }
	
	my $i;
	for($i=0; $i<=$#{$self->{'news'}}; ++$i)
	{
		if( $self->{'news'}[$i]->equals($news) )
		{
			
			return $self->{'news'}[$i]->getAgeMinutes();
		}
	}
	die "does not contain";
	return 0; # die?
}

sub count {
	my $self = pop @_;
	
	return( $#{$self->{'news'}} +1);
}

1;
