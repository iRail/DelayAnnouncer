################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Trend::Station::ConsecutiveDelayed;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use Lingua::EN::Inflect qw/:ALL/;
use List::Util qw/sum/;

# Write nicely
use strict;
use warnings;

# Roles
with 'WWW::IRail::DelayAnnouncer::Trend::Station';

# Package information
our $ENABLED = 1;

# Delay messages
my @CATEGORIES = qw/2 3 4 5 6 7 8 9/;
my @MESSAGES = (
	'$station just scored a Double Delay',
	'$station just scored a Triple Delay',
	'$station just scored a Multi Delay',
	'$station just scored a Mega Delay',
	'$station just scored a Ultra Delay',
	'$station just scored a M-M-M-M-Monster Delay',
	'$station just scored a LUDICROUS Delay',
	'H O L Y  S H I T'
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

sub expiry {
	return 3600 * 4;
}

sub calculate_score {
	my ($self) = @_;
	
	my @departures = $self->storage->get_past_departures_consecutively_delayed($self->station);
	my $amount = (scalar @departures);
	DEBUG "Amount of consecutively delayed trains: $amount";
	
	my $category = 0;
	while ($category != scalar @CATEGORIES && $amount >= $CATEGORIES[$category]) {
		$category++;
	}
	DEBUG "Score category: $category";
	
	return $category;
};

sub message {
	my ($self, $score) = @_;
		
	my $streak = $MESSAGES[$score-1];
	my $station = $self->stationname;
	$streak =~ s/\$station/$station/g;
	
	return $streak . " ("
		. NO("delay", $CATEGORIES[$score-1])
		. " in a row)";
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
