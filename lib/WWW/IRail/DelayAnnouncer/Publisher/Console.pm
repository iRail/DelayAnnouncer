################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Publisher::Console;

# Packages
use Moose;
use Log::Log4perl qw(:easy);

# Write nicely
use strict;
use warnings;

# Roles
with 'WWW::IRail::DelayAnnouncer::Publisher';


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

sub publish {
	my ($self, $message) = @_;
	
	INFO "Console publish: " . $message;
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