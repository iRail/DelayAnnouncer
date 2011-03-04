################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Achievement;

# Packages
use Moose::Role;

# Write nicely
use strict;
use warnings;


################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=cut

has 'storage' => (
	is		=> 'rw',
	isa		=> 'HashRef',
	default		=> sub { {} }
);


################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

sub id {
	my ($self) = @_;
	
	my $class = ref($self);
	my @parts = split(/::/, $class);
	return $parts[-1];
}

requires 'init_storage';

requires 'check';

requires 'message';

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