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

# Roles
with 'WWW::IRail::DelayAnnouncer::Plugin';


################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=cut

has 'bag' => (
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

requires 'owner';

requires 'init_bag';

requires 'messages';

around 'messages' => sub {
	my $orig = shift;
	my $self = shift;
	
	my $messages = $self->$orig(@_);
	foreach my $message (@$messages) {
		$message = "Achievement unlocked: $message.";
	}
	
	return $messages;
};

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