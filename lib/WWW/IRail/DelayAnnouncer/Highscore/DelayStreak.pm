################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Highscore::DelayStreak;

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

# Streak messages
my %STREAKS = (
	10	=> '$station is on a Delay Spree',
	20	=> '$station is Dominating',
	30	=> '$station is on a Rampage',
	40	=> '$station is Unstoppable',
	50	=> '$station is Godlike',
	65	=> '$station is Wicked sick'
);


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
	
	my @departures = $database->get_departure_range(time-3600);
	my $amount = (scalar @departures);
	DEBUG "Amount of delays in the past hour: $amount";
	if ($amount > 1) {
		return $amount;
	} else {
		return undef;
	}
};

sub message {
	my ($self, $station, $score) = @_;
		
	if (defined $STREAKS{$score}) {
		my $streak = $STREAKS{$score};
		$streak =~ s/\$station/$station/g;
		return $streak . " ("
			. NO("train", $score)
			. " delayed)";
	} else {
		return "H O L Y  S H I T ("
			. NO("train", $score)
			. " delays in a row)";
	}
}

sub global_message {
	my ($self, $station, $previous_station, $score) = @_;
	
	if (defined $previous_station) {
		return "$station just ousted $previous_station as leader of delay streaks";		
	} else {
		return "$station just became leader of delay streaks";
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
