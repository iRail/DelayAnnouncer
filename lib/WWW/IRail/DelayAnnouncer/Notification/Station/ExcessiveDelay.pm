################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Notification::Station::ExcessiveDelay;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use List::Util qw(max);
use Lingua::EN::Inflect qw/:ALL/;

# Write nicely
use strict;
use warnings;

# Roles
with 'WWW::IRail::DelayAnnouncer::Notification::Station';

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

sub messages {
	my ($self) = @_;
	
	# Process all departures
	my @messages;
	foreach my $departure (@{$self->storage->current_liveboard($self->station)->departures()}) {
		if ($departure->delay > 0) {
			my $delay = int($departure->delay / 60);
			my $previous_delay = $self->get_data($departure->direction, $departure->time) || 0;
			if ($delay > $previous_delay + 30) {
				$delay = $delay - $delay % 30;
				$self->set_data($departure->direction ,$departure->time, $delay);
				my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($departure->time);
				push @messages, [ "info", "the train of "
					. sprintf("%02i:%02i", $hour, $min)
					. " to "
					. $self->storage->get_station_name($departure->direction)
					. " has over "
					. NO("minute", $delay)
					. " of delay" ];
			}
		}
	}
	return \@messages;
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
