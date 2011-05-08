################################################################################
# Configuration
#

# Package definition
package WWW::IRail::API2::Liveboard;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use WWW::IRail::API2;
use WWW::IRail::API2::Departure;
use WWW::IRail::API2::Arrival;

# Write nicely
use strict;
use warnings;


################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=cut

has 'api' => (
	is		=> 'ro',
	isa		=> 'WWW::IRail::API2',
	lazy		=> 1,
	builder		=> '_build_api'
);

sub _build_api {
	my ($self) = @_;
	
	return new WWW::IRail::API2;
}

has 'station' => (
	is		=> 'ro',
	isa		=> 'Str',
	required	=> 1
);

has 'timestamp' => (
	is		=> 'rw',
	isa		=> 'Int',
	default		=> sub { 0 }
);

has 'departures' => (
	is		=> 'rw',
	isa		=> 'ArrayRef',
	lazy		=> 1,
	builder		=> '_build_departures'
);

sub _build_departures {
	my ($self) = @_;
	
	my ($departures, $stations, $timestamp) = $self->api->liveboard_departures($self->station);
	$self->timestamp($timestamp);
	push @{$self->internal_stations}, @{$stations};
	
	return $departures;
}

has 'arrivals' => (
	is		=> 'rw',
	isa		=> 'ArrayRef',
	lazy		=> 1,
	builder		=> '_build_arrivals'
);

sub _build_arrivals {
	my ($self) = @_;
	
	my ($arrivals, $stations, $timestamp) = $self->api->liveboard_arrivals($self->station);
	$self->timestamp($timestamp);
	push @{$self->internal_stations}, @{$stations};
	
	return $arrivals;
}

has 'internal_stations' => (
	is		=> 'ro',
	isa		=> 'ArrayRef',
	default		=> sub { [] }
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
