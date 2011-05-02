################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Achievement::Station::TrainDelay;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use List::Util qw(max);
use Lingua::EN::Inflect qw/:ALL/;

# Write nicely
use strict;
use warnings;

# Roles
with 'WWW::IRail::DelayAnnouncer::Achievement::Station';

# Package information
our $ENABLED = 1;


################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=cut


################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

sub init_bag {
	my ($self) = @_;
	
	$self->bag->{delay} = 0;
}

sub messages {
	my ($self) = @_;
	
	# Calculate delay
	my $delay = ( max
		map { $_->delay }
		@{$self->storage->current_liveboard($self->station)->departures()} ) || 0;
	$delay  = int($delay / 60);
	DEBUG "Maximum delay: " . NO("minute", $delay);
	
	# Check
	DEBUG "Stored delay: " . $self->bag->{delay};
	if ($delay > ($self->bag->{delay} + 10)) {
		DEBUG "Current delay is 10 minutes higher, triggering message";
		$self->bag->{delay} = $delay - $delay % 10;
		
		return [ 'delay a train '
			. NO("minute", $self->bag->{delay})
			. ' or more' ];
	}	
	return [];
}


42;

__END__

=pod

=head1 COPYRIGHT

Copyright 2011 The iRail development team as listed in the AUTHORS file.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut