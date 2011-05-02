################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Achievement::Station::TotalPercentage;

# Packages
use Moose;
use Log::Log4perl qw(:easy);

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
	
	$self->bag->{percentage} = 0;
}

sub messages {
	my ($self) = @_;
	
	# At least 5 trains
	my $total = scalar @{$self->storage->current_liveboard($self->station)->departures()};
	DEBUG "Found $total trains";
	if ($total < 10) {
		DEBUG "Bailing out, need at least 10 trains";
		return [];
	}
	
	# Calculate percentage
	my $delayed = scalar
		grep { $_->delay > 0 }
		@{$self->storage->current_liveboard($self->station)->departures()};	
	my $percentage = int (100 * $delayed / $total);
	DEBUG "Found $delayed delayed trains (or $percentage%)";
	
	# Check
	DEBUG "Stored percentage: " . $self->bag->{percentage};
	if ($percentage > ($self->bag->{percentage} + 10)) {
		DEBUG "Current amount is 10% higher, triggering message";
		$self->bag->{percentage} = $percentage - $percentage % 10;
		
		return [ 'delay at least '
			. $self->bag->{percentage}
			. '% of the trains' ];
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
