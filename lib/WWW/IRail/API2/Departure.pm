################################################################################
# Configuration
#

# Package definition
package WWW::IRail::API2::Departure;

# Packages
use Moose;
use Log::Log4perl qw(:easy);

# Write nicely
use strict;
use warnings;


################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=cut

has 'direction' => (
	is		=> 'ro',
	isa		=> 'Str',
	required	=> 1
);

has 'time' => (
	is		=> 'ro',
	isa		=> 'Int',
	required	=> 1

);

has 'vehicle' => (
	is		=> 'ro',
	isa		=> 'Maybe[Str]'
);

has 'platform' => (
	is		=> 'ro',
	isa		=> 'Maybe[Str]'
);

has 'delay' => (
	is		=> 'ro',
	isa		=> 'Int',
	default		=> 0
);


################################################################################
# Methods
#

=pod

=head1 METHODS

=cut


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
