################################################################################
# Configuration
#

# Package definition
package WWW::IRail::API2;

# Packages
use Moose;
use JSON;
use LWP::UserAgent;
use URI::Escape ('uri_escape');
use Log::Log4perl qw(:easy);
use WWW::IRail::API2::Liveboard;
use WWW::IRail::API2::Station;
use WWW::IRail::API2::Departure;

# Write nicely
use strict;
use warnings;


################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=cut

has 'base' => (
	is		=> 'ro',
	isa		=> 'Str',
	default		=> sub { 'http://api.irail.be/' }
);

has 'json' => (
	is		=> 'ro',
	isa		=> 'JSON',
	default		=> sub { new JSON }
);

has 'ua' => (
	is		=> 'ro',
	isa		=> 'LWP::UserAgent',
	default		=> sub { new LWP::UserAgent(agent => 'irail-harvester') }
);



################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

sub stations {
	my ($self) = @_;
	
	my $url = $self->base . 'stations.php'
		.'?format=json';
	DEBUG "Requestion station list via " . $url;
	
	# Fetch response
	my $response = $self->ua()->get($url);
	unless($response->is_success) {
		WARN "Could not fetch station data";
		WARN $response->status_line;
		return undef;
	}
	
	# Decode data
	my $data;
	eval {
		$data = $self->json()->decode($response->decoded_content);
	};
	if ($@) {
		WARN "Could not decode station data";
		WARN $@;
		DEBUG $response->decoded_content;
		return undef;
	}
	
	# Process data
	my @stations;
	my $timestamp = $data->{timestamp};
	my $stations = $data->{station};	
	foreach my $station (@{$stations}) {
		push @stations, new WWW::IRail::API2::Station(
			id		=> $station->{id},
			name		=> $station->{name},
			longitude	=> $station->{locationX},
			latitude	=> $station->{locationY}
		);
	}
	
	return \@stations;
}

sub liveboard_departures {
	my ($self, $station) = @_;
	
	my $url = $self->base . 'liveboard.php'
		. '?station=' . uri_escape($station)
		.'&format=json';
	DEBUG "Requestion liveboard departures via " . $url;
		
	# Fetch response
	my $response = $self->ua()->get($url);
	unless($response->is_success) {
		WARN "Could not fetch liveboard data";
		WARN $response->status_line;
		return undef;
	}
	
	# Decode data
	my $data;
	eval {
		$data = $self->json()->decode($response->decoded_content);
	};
	if ($@) {
		WARN "Could not decode liveboard data";
		WARN $@;
		DEBUG $response->decoded_content;
		return undef;
	}
	
	# Process data
	DEBUG "Fetched liveboard departures";
	my $timestamp = $data->{timestamp};
	my $departures_data = $data->{departures}{departure};	
	my (@departures, @stations);
	foreach my $departure_data (@{$departures_data}) {
		my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($departure_data->{time});
		DEBUG "Departure at "
			. sprintf("%02i:%02i", $hour, $min)
			. " to " . $departure_data->{station}
			. ", on platform "
			. $departure_data->{platform};
		if ($departure_data->{platform} eq "") {
			$departure_data->{platform} = undef;
		}
		push @departures, new WWW::IRail::API2::Departure(
			direction	=> $departure_data->{stationinfo}->{id},
			'time'		=> $departure_data->{'time'},
			platform	=> $departure_data->{platform},
			vehicle		=> $departure_data->{vehicle},
			delay		=> $departure_data->{delay}
		);
		push @stations, new WWW::IRail::API2::Station(
			id		=> $departure_data->{stationinfo}->{id},
			name		=> $departure_data->{stationinfo}->{name},
			longitude	=> $departure_data->{stationinfo}->{locationX},
			latitude	=> $departure_data->{stationinfo}->{locationY}
		);
	}
	return \@departures, \@stations, $timestamp;
}

sub liveboard_arrivals {
	my ($self, $station) = @_;
	
	my $url = $self->base . 'liveboard.php'
		. '?station=' . uri_escape($station)
		.'&arrdep=A'
		.'&format=json';
	DEBUG "Requestion liveboard arrivals via " . $url;
		
	# Fetch response
	my $response = $self->ua()->get($url);
	unless($response->is_success) {
		WARN "Could not fetch liveboard data";
		WARN $response->status_line;
		return undef;
	}
	
	# Decode data
	my $data;
	eval {
		$data = $self->json()->decode($response->decoded_content);
	};
	if ($@) {
		WARN "Could not decode liveboard data";
		WARN $@;
		DEBUG $response->decoded_content;
		return undef;
	}
	
	# Process data
	DEBUG "Fetched liveboard arrivals";
	my $timestamp = $data->{timestamp};
	my $arrivals_data = $data->{departures}{departure};	
	my (@arrivals, @stations);
	foreach my $arrival_data (@{$arrivals_data}) {
		my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($arrival_data->{time});
		DEBUG "Arrival at "
			. sprintf("%02i:%02i", $hour, $min)
			. " from " . $arrival_data->{station}
			. ", on platform "
			. $arrival_data->{platform};
		if ($arrival_data->{platform} eq "") {
			$arrival_data->{platform} = undef;
		}
		push @arrivals, new WWW::IRail::API2::Departure(
			origin		=> $arrival_data->{stationinfo}->{id},
			'time'		=> $arrival_data->{'time'},
			platform	=> $arrival_data->{platform},
			vehicle		=> $arrival_data->{vehicle},
			delay		=> $arrival_data->{delay}
		);
		push @stations, new WWW::IRail::API2::Station(
			id		=> $arrival_data->{stationinfo}->{id},
			name		=> $arrival_data->{stationinfo}->{name},
			longitude	=> $arrival_data->{stationinfo}->{locationX},
			latitude	=> $arrival_data->{stationinfo}->{locationY}
		);
	}
	return \@arrivals, \@stations, $timestamp;
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
