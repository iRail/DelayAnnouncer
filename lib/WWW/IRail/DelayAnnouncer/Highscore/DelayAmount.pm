################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Highscore::DelayAmount;

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
	
	my $amount = sum
		grep { $_->{delay} }
		@{$database->current_liveboard()->departures()};
	DEBUG "Delay amount: $amount";
	return $amount;
};

sub message {
	my ($self, $station, $score) = @_;
	
	return "$station just predicted "
		. NO("minute", $score)
		. " of delay for the next hour";
}

sub global_message {
	my ($self, $station, $previous_station, $score) = @_;
	
	if (defined $previous_station) {
		return "$station just ousted $previous_station as leader in amount of delay for the next hour";		
	} else {
		return "$station just became leader in amount of delay for the next hour";
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
