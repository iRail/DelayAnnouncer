################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Achievement::Station::Terminus;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use Lingua::EN::Inflect qw/:ALL/;

# Write nicely
use strict;
use warnings;

# Roles
with 'WWW::IRail::DelayAnnouncer::Achievement::Station';

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

sub init_bag {
	my ($self) = @_;
}

sub messages {
	my ($self) = @_;
	
	# Fetch per-terminus delays
	my %termini_stats;
	foreach my $departure (@{$self->storage->current_liveboard($self->station)->departures()}) {
		my @stats = (0, 0);
		if (defined $termini_stats{$departure->direction}) {
			@stats = @{$termini_stats{$departure->direction}};
		}
		$stats[0]++;
		if ($departure->{delay} > 0) {
			$stats[1]++;
		}
		$termini_stats{$departure->direction} = \@stats;
	}
	
	# Check them
	my @messages;
	foreach my $terminus (keys %termini_stats) {
		my @stats = @{$termini_stats{$terminus}};
		my $previous = $self->bag->{$terminus} || 0;
		DEBUG "Found " . $stats[0]
			. " trains to "
			. $self->storage->get_station_name($terminus)
			. " ("
			. $stats[1]
			. " delayed, previous limit was "
			. $previous
			. ")";
		if ($stats[0] >= 3) { # We need at-least 3 departures
			if ($stats[0] == $stats[1] && $stats[1] > $previous) {
				DEBUG "Pushing message";
				push @messages, "delay all "
					. NO("train", $stats[1])
					. " to "
					. $self->storage->get_station_name($terminus);
				$self->bag->{$terminus} = $stats[1];
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