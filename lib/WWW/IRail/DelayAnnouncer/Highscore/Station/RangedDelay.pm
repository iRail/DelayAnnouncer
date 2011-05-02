################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Highscore::Station::RangedDelay;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use List::Util qw/sum/;
use Time::Duration;

# Write nicely
use strict;
use warnings;

# Package information
our $ENABLED = 0;


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

sub _calculate_score {
	my ($self, $range) = @_;
	
	my $start = time() - $range;
	
	my $earliest_departure = $self->storage->get_earliest_departure($self->station);
	
	if ($earliest_departure->time > $start) {
		DEBUG "Bailing out, earliest departure falls within the range.";
		return undef;
	}
	
	my @departures = $self->storage->get_departure_range($self->station, $start);
	my $delay = sum
		map { $_->delay }
		@departures;
	DEBUG "Accumulated delay: " . duration($delay);
	return $delay;
};

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
