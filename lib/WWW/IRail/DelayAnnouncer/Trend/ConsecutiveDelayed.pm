################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Trend::ConsecutiveDelayed;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use Lingua::EN::Inflect qw/:ALL/;
use List::Util qw/sum/;

# Write nicely
use strict;
use warnings;

# Roles
with 'WWW::IRail::DelayAnnouncer::Trend';

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
	'$station just scored a Monster Delay',
	'$station just scored a Ludicrous Delay',
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
	my ($self, $database) = @_;
	
	my @departures = $database->get_past_departures_consecutively_delayed();
	my $amount = (scalar @departures);
	DEBUG "Amount of consecutively delayed trains: $amount";
	
	my $category = 0;
	while ($amount > $CATEGORIES[$category] && $category != scalar @CATEGORIES) {
		$category++;
	}
	DEBUG "Score category: $category";
	
	return $category;
};

sub message {
	my ($self, $station, $score) = @_;
		
	my $streak = $MESSAGES[$score-1];
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
