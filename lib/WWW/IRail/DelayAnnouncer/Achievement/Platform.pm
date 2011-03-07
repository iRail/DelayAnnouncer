################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Achievement::Platform;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use Lingua::EN::Inflect qw/:ALL/;

# Write nicely
use strict;
use warnings;

# Roles
with 'WWW::IRail::DelayAnnouncer::Achievement';

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

sub init_storage {
	my ($self) = @_;
}

sub messages {
	my ($self, $database) = @_;
	
	# Fetch per-terminus delays
	my %platforms_stats;
	foreach my $departure (@{$database->current_liveboard()->departures()}) {
		next unless (defined $departure->{platform});
		my @stats = (0, 0);
		if (defined $platforms_stats{$departure->{platform}}) {
			@stats = @{$platforms_stats{$departure->{platform}}};
		}
		$stats[0]++;
		if ($departure->{delay} > 0) {
			$stats[1]++;
		}
		$platforms_stats{$departure->{platform}} = \@stats;
	}
	
	# Check them
	my @messages;
	foreach my $platform (keys %platforms_stats) {
		my @stats = @{$platforms_stats{$platform}};
		my $previous = $self->storage()->{$platform} || 0;
		DEBUG "Found " . $stats[0]
			. " trains on platform $platform ("
			. $stats[1]
			. " delayed, previous limit was "
			. $previous
			. ")";
		if ($stats[0] >= 3) { # We need at-least 3 departures
			if ($stats[0] == $stats[1] && $stats[1] > $previous) {
				DEBUG "Pushing message";
				push @messages, 'delay all '
					. NO("train", $stats[1])
					. ' on platform '
					. $platform;
				$self->storage()->{$platform} = $stats[1];
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