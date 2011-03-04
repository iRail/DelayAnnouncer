################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Achievement::TotalPercentage;

# Packages
use Moose;
use Log::Log4perl qw(:easy);

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
	
	$self->storage()->{percentage} = 0;
}

sub messages {
	my ($self, $database) = @_;
	
	# At least 5 trains
	my $total = scalar @{$database->current_liveboard()->departures()};
	DEBUG "Found $total trains";
	if ($total < 5) {
		DEBUG "Bailing out, need at least 5 trains";
		return [];
	}
	
	# Calculate percentage
	my $delayed = scalar
		grep { $_->{delay} > 0 }
		@{$database->current_liveboard()->departures()};	
	my $percentage = int (100 * $delayed / $total);
	DEBUG "Found $delayed delayed trains (or $percentage%)";
	
	# Check
	DEBUG "Stored percentage: " . $self->storage()->{percentage};
	if ($percentage > ($self->storage()->{percentage} + 25)) {
		DEBUG "Current amount is 25% higher, triggering message";
		$self->storage()->{percentage} += 25;
		
		return [ 'Achievement unlocked: delay at least '
			. $self->storage()->{percentage}
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