################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Highscore;

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


################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

requires 'calculate_score';

requires 'message';

around 'message' => sub {
	my $orig = shift;
	my $self = shift;
	
	my $message = $self->$orig(@_);
	$message = "New highscore: $message!";
	
	return $message;
};

requires 'global_message';

around 'global_message' => sub {
	my $orig = shift;
	my $self = shift;
	
	my $message = $self->$orig(@_);
	$message = "Leadership change: $message!";
	
	return $message;
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