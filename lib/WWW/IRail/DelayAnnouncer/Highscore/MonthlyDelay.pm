################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Highscore::MonthlyDelay;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use Time::Duration;

# Write nicely
use strict;
use warnings;

# Roles
with 'WWW::IRail::DelayAnnouncer::Highscore';

# Base class
extends 'WWW::IRail::DelayAnnouncer::Highscore::RangedDelay';

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
	
	return $self->_calculate_score($database, 30 * 7 * 24 * 3600);
};

sub message {
	my ($self, $station, $score) = @_;
	
	return "$station just accomplished "
		. duration($score)
		. " of delay in a single month";
}

sub global_message {
	my ($self, $station, $previous_station, $score) = @_;
	
	if (defined $previous_station) {
		return "$station just ousted $previous_station as leader of the monthly delay rankings";		
	} else {
		return undef;
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
