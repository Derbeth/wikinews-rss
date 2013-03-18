package RSS::VulgarismDetector;
use strict;
use utf8;

sub new {
	my ($class, @vulgarisms) = @_;
	my $self = {'vulgarisms' => @vulgarisms};
	bless($self, $class);
	return $self;
}

sub detect {
	my ($self, $text) = @_;
	foreach my $vulgarism (@{$self->{vulgarisms}}) {
		if( $text =~ /$vulgarism/si ) {
			return $vulgarism;
		}
	}
	return undef;
}

1;
