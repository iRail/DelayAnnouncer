################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Achievement::TrainDelay;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use List::Util qw(max);
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
	
	$self->storage()->{delay} = 0;
}

sub messages {
	my ($self, $database) = @_;
	
	# Calculate delay
	my $delay = max
		map { $_->{delay} }
		@{$database->current_liveboard()->departures()};
	$delay /= 60;
	DEBUG "Maximum delay: $delay";
	
	# Check
	DEBUG "Stored delay: " . $self->storage()->{delay};
	if ($delay > ($self->storage()->{delay} + 30)) {
		DEBUG "Current delay is 30 minutes higher, triggering message";
		$self->storage()->{delay} += 30;
		
		return [ 'delay a train '
			. NO("minute", $self->storage()->{delay}) ];
	}	
	return [];
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