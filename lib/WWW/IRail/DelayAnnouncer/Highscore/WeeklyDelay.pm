################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Highscore::WeeklyDelay;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use Lingua::EN::Inflect qw/:ALL/;
use List::Util qw/sum/;
use Time::Duration;

# Write nicely
use strict;
use warnings;

# Roles
with 'WWW::IRail::DelayAnnouncer::Highscore';


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

sub calculate_score {
	my ($self, $database) = @_;
	
	my $start = time() - 7 * 24 * 3600;
	
	my $earliest_departure = $database->get_earliest_departure();
	use Data::Dumper; print Dumper($earliest_departure);
	if ($earliest_departure->{time} > $start) {
		DEBUG "Bailing out, earliest departure not yet a week ago.";
		return undef;
	}
	
	my @departures = $database->get_departure_range($start);
	my $delay = sum
		map { $_->{delay} }
		@departures;
	DEBUG "Accumulated delay: " . duration($delay);
	return $delay;
};

sub message {
	my ($self, $station, $score) = @_;
	
	return "$station just pushed its weekly-accumulated delay to "
		. duration($score);
}

sub global_message {
	my ($self, $station, $previous_station, $score) = @_;
	
	if (defined $previous_station) {
		return "$station just ousted $previous_station as leader of total delay in a single week";		
	} else {
		return "$station just became leader of total delay in a single week";
	}
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
