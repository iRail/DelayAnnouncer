################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Trend::DelayStreak;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use Lingua::EN::Inflect qw/:ALL/;
use List::Util qw/max/;

# Write nicely
use strict;
use warnings;

# Roles
with 'WWW::IRail::DelayAnnouncer::Trend';

# Package information
our $ENABLED = 1;

# Streak messages
my @CATEGORIES = qw/10 20 30 40 50 60 70/;
my @MESSAGES = (
	'$station is on a Delay Spree',
	'$station is Dominating',
	'$station is on a Rampage',
	'$station is Unstoppable',
	'$station is Godlike',
	'$station is Wicked sick',
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
	return 3600 * 6;
}

sub calculate_score {
	my ($self, $database) = @_;
	
	my @departures = $database->get_departure_range(time-3600);
	my $delayed = scalar grep { $_->{delay} > 0 } @departures;
	my $amount = scalar @departures;
	DEBUG "Amount of delays in the past hour: $delayed (on a total of $amount)";
	
	my $category = 0;
	while ($category != scalar @CATEGORIES && $delayed >= $CATEGORIES[$category]) {
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
		. " in one hour)";
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
