################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Notification::Station::Cancellations;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use List::Util qw(max);
use Lingua::EN::Inflect qw/:ALL/;
use Time::Duration;

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
	return [] unless (defined $self->storage->previous_liveboard($self->station));
	
	# Process all previous departures
	my @messages;
	foreach my $previous_departure (@{$self->storage->previous_liveboard($self->station)->departures()}) {		
		# Check current liveboard
		my $found = 0;
		foreach my $current_departure (@{$self->storage->current_liveboard($self->station)->departures()}) {
			if ($previous_departure->direction eq $current_departure->direction
				&& $previous_departure->time == $current_departure->time) {
				$found = 1;
				last;
			}
		}
		next if ($found);
		
		# Has the train left?
		next if (time - $previous_departure->time > 60);
		
		# A train without delay "can't" get cancelled
		next unless ($previous_departure->delay);
		
		my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($previous_departure->time);
		push @messages, [ "warn", "the train of "
			. sprintf("%02i:%02i", $hour, $min)
			. " to "
			. $self->storage->get_station_name($previous_departure->direction)
			. " seems to have been canceled (it had a delay of "
			. duration($previous_departure->delay)
			. ")" ];
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
