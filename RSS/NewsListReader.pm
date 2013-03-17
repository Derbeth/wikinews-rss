package RSS::NewsListReader;
use strict;
use utf8;

use RSS::Status;

# Const: $MAX_FETCH_FAILURES
#   how many fetch failures can be tollerated
my $MAX_FETCH_FAILURES = 20;

# Const: $ERROR_CLEAR_DELAY
#   after n main loops error count will be decreased by one
#   As result, every ($CHECKOUT_PAUSE * $ERROR_CLEAR_DELAY) minutes error number
#   will be reduced by one
#
#   Should be greater than $MAX_FETCH_FAILURES
my $ERROR_CLEAR_DELAY=20;

sub new {
	my ($class) = @_;
	my $self = {};
	bless($self, $class);
	# internal variable, counts fetch failures for <fetch_news_list()>
	$self->{'fetch_failures'} = 0;
	$self->{'loop_count'}=1;
	return $self;
}

sub fetch_titles {
	die "unimplemented";
}

sub report_fetch_failure {
	my ($self, $error_msg) = @_;
	my $now = localtime();
	print "$now:  $error_msg\n";
	if( ++$self->{fetch_failures} >= $MAX_FETCH_FAILURES ) {
		set_status(2);
		die "too many errors ($self->{fetch_failures})";
	}
}

sub clear_errors {
	my($self) = @_;
	$self->{loop_count}=($self->{loop_count}+1) % $ERROR_CLEAR_DELAY;
	if( $self->{loop_count} == 0 && $self->{fetch_failures} > 0 ) {
		--$self->{fetch_failures};
	}
}

1;
