################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Highscore::ConsecutiveDelayed;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use Lingua::EN::Inflect qw/:ALL/;
use List::Util qw/sum/;

# Write nicely
use strict;
use warnings;

# Roles
with 'WWW::IRail::DelayAnnouncer::Highscore';

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

sub calculate_score {
	my ($self, $database) = @_;
	
	my @departures = $database->get_past_departures_consecutively_delayed();
	my $amount = (scalar @departures);
	DEBUG "Amount of consecutively delayed trains: $amount";
	if ($amount > 1) {
		return $amount;
	} else {
		return undef;
	}
};

sub message {
	my ($self, $station, $score) = @_;
	
	return "$station just managed to delay "
		. NO("train", $score)
		. " in a row";
}

sub global_message {
	my ($self, $station, $previous_station, $score) = @_;
	
	if (defined $previous_station) {
		return "$station just ousted $previous_station as leader of consecutive delays";		
	} else {
		return "$station just became leader in amount of consecutive delays";
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
