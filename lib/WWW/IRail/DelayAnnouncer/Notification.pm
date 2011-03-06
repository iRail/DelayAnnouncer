################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Notification;

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

sub get_data {
	my ($self, $database, $station, $time) = @_;
	
	return $database->get_notification_data($self->id(), $station, $time);
}

sub set_data {
	my ($self, $database, $station, $time, $data) = @_;
	
	return $database->set_notification_data($self->id(), $station, $time, $data);
}

requires 'messages';

around 'messages' => sub {
	my $orig = shift;
	my $self = shift;
	
	my $messages = $self->$orig(@_);
	foreach my $message (@$messages) {
		my ($level, $text) = @$message;
		if ($level eq "info") {
			$message = "Newsflash: $text.";
		} elsif ($level eq "warn") {
			$message = "Watch out: $text!";
		}
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
