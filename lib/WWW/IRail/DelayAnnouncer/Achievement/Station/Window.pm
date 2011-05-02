################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Achievement::Station::Window;

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
	
	$self->bag()->{window} = 0;
}

sub messages {
	my ($self) = @_;
	
	# Get and sort departures
	my @departures = sort { $a->time <=> $b->time }
		@{$self->storage->current_liveboard($self->station)->departures()};
	
	# Get the delay window (e.g. from the soonest to depart train,
	# to the first non-delayed one)
	my $amount = 0;
	my ($start, $end) = (time, time);
	foreach my $departure (@departures) {
		$end = $departure->time;
		last unless ($departure->delay);
		if ($start > $departure->time) {
			# In case a delayed train should already have left
			$start = $departure->time;
		}
		$amount++;
	}
	my $window = ($end - $start) / 60;
	DEBUG "Calculated delay window of $window minutes for $amount trains";
	if ($amount < 3) {
		DEBUG "Bailing out, need at least 3 trains within the window";
		return [];
	}
	
	# Workaround for a bug in the API
	if ($window > 720) {
		return undef;
	}
	
	# Check
	DEBUG "Stored window " . $self->bag->{window};
	if ($window > ($self->bag->{window} + 5)) {
		DEBUG "Current window is 5 minutes longer, triggering message";
		$self->bag->{window} = $window - $window % 5;
		
		return [ 'delay all trains within the next '
			. NO("minute", $self->bag->{window}) ];
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