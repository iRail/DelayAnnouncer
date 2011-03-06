################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Achievement::Window;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use Lingua::EN::Inflect qw/:ALL/;

# Write nicely
use strict;
use warnings;

# Roles
with 'WWW::IRail::DelayAnnouncer::Achievement';


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
	
	$self->storage()->{window} = 0;
}

sub messages {
	my ($self, $database) = @_;
	
	# Get and sort departures
	my @departures = sort { $a->{time} <=> $b->{time} }
		@{$database->current_liveboard()->departures()};
	
	# Get the delay window (e.g. from the soonest to depart train,
	# to the first non-delayed one)
	my $amount = 0;
	my ($start, $end) = (time, time);
	foreach my $departure (@departures) {
		$end = $departure->{time};
		last unless ($departure->{delay});
		if ($start > $departure->{time}) {
			# In case a delayed train should already have left
			$start = $departure->{time};
		}
		$amount++;
	}
	my $window = ($end - $start) / 60;
	DEBUG "Calculated delay window of $window minutes for $amount trains";
	if ($amount < 3) {
		DEBUG "Bailing out, need at least 3 trains within the window";
		return [];
	}
	
	# Check
	DEBUG "Stored window " . $self->storage()->{window};
	if ($window > ($self->storage()->{window} + 5)) {
		DEBUG "Current window is 5 minutes longer, triggering message";
		$self->storage()->{window} = $window - $window % 5;
		
		return [ 'delay all trains within the next '
			. NO("minutes", $self->storage()->{window}) ];
	}	
	return []
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