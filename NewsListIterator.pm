#!/usr/bin/perl

package NewsListIterator;

use strict 'vars';

sub new {
	#pop @_; # class name
	my $list = \pop @_;
	
	my $self = {};
   bless($self, "NewsListIterator");
   
   $self->{'list'} = $list;
   $self->{'position'} = 0;
   
   return $self;
}

sub start {
	my $self = pop @_;
	
	$self->{'position'} = 0;
}

sub hasNext {
	my $self = pop @_;
	#print "position: " . $self->{'position'};
	
	return( $self->{'position'} <= $#{${$self->{'list'}}->{'news'}} );
}

sub getNext {
	my $self = pop @_;
	my $retval;
	
	$retval = ${$self->{'list'}}->{'news'}[ $self->{'position'}++ ];
	return $retval;
}

1;
