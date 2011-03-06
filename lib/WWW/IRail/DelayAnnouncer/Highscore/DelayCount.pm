################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Highscore::DelayCount;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use Lingua::EN::Inflect qw/:ALL/;

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
	my ($self, $liveboard) = @_;
	
	my $count = scalar
		grep { $_->{delay} }
		@{$liveboard->departures()};
	DEBUG "Delay count: $count";
	return $count;
};

sub message {
	my ($self, $station, $score) = @_;
	
	return "$station just delayed "
		. $score
		. " of the upcoming trains for the next hour";
}

sub global_message {
	my ($self, $station, $previous_station, $score) = @_;
	
	if (defined $previous_station) {
		return "$station just ousted $previous_station as leader of delayed trains for the next hour";		
	} else {
		return "$station just became leader of delayed trains for the next hour";		
	}
}

0;

__END__

=pod

=head1 COPYRIGHT

Copyright 2011 The iRail development team as listed in the AUTHORS file.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
