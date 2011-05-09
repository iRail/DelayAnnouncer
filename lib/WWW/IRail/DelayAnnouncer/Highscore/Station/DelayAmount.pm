################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Highscore::Station::DelayAmount;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use Lingua::EN::Inflect qw/:ALL/;
use List::Util qw/sum/;

# Write nicely
use strict;
use warnings;

# Roles
with 'WWW::IRail::DelayAnnouncer::Highscore::Station';

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

sub calculate_score {
	my ($self) = @_;
	
	my $amount = sum
		grep { $_->delay }
		@{$self->storage->current_liveboard($self->station)->departures()};
	$amount = int($amount/60);
	DEBUG "Delay amount: " . NO("minute", $amount);
	return $amount;
};

sub message {
	my ($self, $score) = @_;
	
	return $self->stationname
		. " just predicted "
		. NO("minute", $score)
		. " of delay for the next hour";
}

sub global_message {
	my ($self, $previous_station, $score) = @_;
	
	if (defined $previous_station) {
		return $self->stationname
			. " just ousted "
			. $self->storage->get_station_name($previous_station)
			. " as leader of upcoming amount of delay";		
	} else {
		return $self->stationname
			. " just became leader of upcoming amount of delay";
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
