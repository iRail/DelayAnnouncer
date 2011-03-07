################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Notification::ExcessiveDelay;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use List::Util qw(max);
use Lingua::EN::Inflect qw/:ALL/;

# Write nicely
use strict;
use warnings;

# Roles
with 'WWW::IRail::DelayAnnouncer::Notification';

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

sub messages {
	my ($self, $database) = @_;
	
	# Process all departures
	my @messages;
	foreach my $departure (@{$database->current_liveboard()->departures()}) {
		if ($departure->{delay} > 0) {
			my $delay = int($departure->{delay} / 60);
			my $previous_delay = $self->get_data($database, $departure->{station}, $departure->{time}) || 0;
			if ($delay > $previous_delay + 15) {
				$delay = $delay - $delay % 15;
				$self->set_data($database, $departure->{station} ,$departure->{time}, $delay);
				my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($departure->{time});
				push @messages, [ "info", "the train of "
					. sprintf("%02i:%02i", $hour, $min)
					. " to "
					. $departure->{station}
					. " has over "
					. NO("minute", $delay)
					. " of delay" ];
			}
		}
	}
	return \@messages;
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
