################################################################################
# Configuration
#

# Package definition
package WWW::IRail::Harvester::Storage;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use DBIx::Log4perl;
use WWW::IRail::API2;
use WWW::IRail::API2::Station;
use WWW::IRail::API2::Liveboard;
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

has 'dbh' => (
	is		=> 'ro',
	isa		=> 'DBI::db',
	required	=> 1
);

has 'liveboards' => (
	is		=> 'ro',
	isa		=> 'HashRef',
	default		=> sub { {} }
);

has 'liveboards_previous' => (
	is		=> 'ro',
	isa		=> 'HashRef',
	default		=> sub { {} }
);

has 'stations' => (
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

sub BUILD {
	my ($self) = @_;
	
	# Station table
	my $sth = $self->dbh()->prepare(<<END
CREATE TABLE IF NOT EXISTS stations (
	id varchar(20) NOT NULL,
	name varchar(40) NOT NULL,
	`timestamp` int(11) NOT NULL,
	longitude dec(9,6) DEFAULT NULL,
	latitude dec(9,6) DEFAULT NULL,
	PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;	
END
	);
	$sth->execute();
	
	# Liveboard table
	$sth = $self->dbh()->prepare(<<END
CREATE TABLE IF NOT EXISTS liveboards (
	station varchar(40) NOT NULL,
	`timestamp` int(11) NOT NULL,
	direction varchar(40) NOT NULL,
	vehicle varchar(20) NOT NULL,
	delay int(11) DEFAULT NULL,
	platform int(11) DEFAULT NULL,
	`time` int(11) NOT NULL,
	PRIMARY KEY (station,`time`,vehicle,`timestamp`),
	FOREIGN KEY (station) REFERENCES stations(id),
	FOREIGN KEY (direction) REFERENCES stations(id),
	KEY `timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;	
END
	);
	$sth->execute();
	
	# Departure table
	$sth = $self->dbh()->prepare(<<END
CREATE TABLE IF NOT EXISTS departures (
	station varchar(40) NOT NULL,
	direction varchar(40) NOT NULL,
	vehicle varchar(20) NOT NULL,
	delay int(11) DEFAULT NULL,
	platform int(11) DEFAULT NULL,
	`time` int(11) NOT NULL,
	PRIMARY KEY (station,`time`,vehicle),
	FOREIGN KEY (station) REFERENCES stations(id),
	FOREIGN KEY (direction) REFERENCES stations(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;	
END
	);
	$sth->execute();
}

sub get_stations {
	my ($self) = @_;
	
	unless (@{$self->stations}) {
		my $sth = $self->dbh()->prepare(<<END
SELECT *
FROM stations
END
		);
		
		$sth->execute();
		
		my @stations;
		while (my $row = $sth->fetchrow_hashref) {
			push @{$self->stations}, new WWW::IRail::API2::Station(%$row);
		}
	}
	
	return $self->stations;
}

sub set_stations {
	my ($self, @stations) = @_;
	
	# Put or update data in stations table
	my $sth = $self->dbh()->prepare(<<END
INSERT
INTO stations(id, name, longitude, latitude, timestamp)
VALUES (?, ?, ?, ?, ?)
ON DUPLICATE KEY UPDATE
	name = VALUES(name),
	longitude = VALUES(longitude),
	latitude = VALUES(latitude)
END
	);
	
	$sth->bind_param_array(1, [ map { $_->id } @stations ]);
	$sth->bind_param_array(2, [ map { $_->name } @stations ]);
	$sth->bind_param_array(3, [ map { $_->longitude } @stations ]);
	$sth->bind_param_array(4, [ map { $_->latitude } @stations ]);
	$sth->bind_param_array(5, time);
	$sth->execute_array( {} );
}

sub get_station_name {
	my ($self, $id) = @_;
	
	return map { $_->name } grep { $_->id eq $id } @{$self->get_stations};
}

sub current_liveboard {
	my ($self, $station) = @_;
	die("Specify a station") unless defined $station;
	
	if (defined $self->liveboards->{$station}) {
		return $self->liveboards->{$station};
	} else {
		my $sth = $self->dbh()->prepare(<<END
SELECT *
FROM liveboards
WHERE station = ? AND timestamp = (
	SELECT max(timestamp)
	FROM liveboards
	WHERE station = ?
)
END
		);

		$sth->bind_param(1, $station);
		$sth->bind_param(2, $station);
		$sth->execute();

		my (@departures, $timestamp);
		while (my $row = $sth->fetchrow_hashref) {
			$timestamp = $row->{timestamp};
			push @departures, new WWW::IRail::API2::Departure(%$row);
		}
		if (@departures) {
			my $liveboard = new WWW::IRail::API2::Liveboard(
				timestamp => $timestamp,
				departures => \@departures
			);
			$self->liveboards->{$station} = $liveboard;
			return $liveboard;
		} else {
			return undef;
		}
	}
}

sub previous_liveboard {
	my ($self, $station) = @_;
	die("Specify a station") unless defined $station;
	
	return $self->liveboards_previous->{$station};
}

sub add_liveboard {
	my ($self, $station, $liveboard) = @_;
	
	# Put data in liveboards table
	my $sth = $self->dbh()->prepare(<<END
INSERT INTO liveboards (station, timestamp, direction, vehicle, delay, platform, time)
VALUES (?, ?, ?, ?, ?, ?, ?)
END
	);	
	$sth->bind_param_array(1, $station);
	$sth->bind_param_array(2, $liveboard->timestamp());
	$sth->bind_param_array(3, [map { $_->{direction} } @{$liveboard->departures()}]);
	$sth->bind_param_array(4, [map { $_->{vehicle} } @{$liveboard->departures()}]);
	$sth->bind_param_array(5, [map { $_->{delay} } @{$liveboard->departures()}]);
	$sth->bind_param_array(6, [map { $_->{platform} } @{$liveboard->departures()}]);
	$sth->bind_param_array(7, [map { $_->{time} } @{$liveboard->departures()}]);	
	$sth->execute_array( {} );
	
	# Put or update data in departures table
	$sth = $self->dbh()->prepare(<<END
REPLACE INTO departures
SELECT liveboard.station,
       liveboard.direction,
       liveboard.vehicle,
       GREATEST(liveboard.delay, COALESCE(departure.delay, 0)),
       liveboard.platform,
       liveboard.time
FROM liveboards liveboard
LEFT JOIN departures departure
	  ON liveboard.station = departure.station
	     AND liveboard.time = departure.time
	     AND liveboard.vehicle = departure.vehicle
WHERE timestamp = ?
END
	);
	$sth->bind_param_array(1, $liveboard->timestamp());
	$sth->execute_array( {} );
	
	# Switch liveboard buffers
	$self->liveboards_previous->{$station} = $self->liveboards->{$station};
	$self->liveboards->{$station} = $liveboard;
}

sub get_departure_range {
	my ($self, $station, $start, $end) = @_;	
	$end = time unless (defined $end);
	
	my $sth = $self->dbh()->prepare(<<END
SELECT direction, vehicle, delay, platform, time
FROM departures
WHERE station = ? AND time BETWEEN ? AND ?
END
	);
	
	$sth->bind_param(1, $station);
	$sth->bind_param(2, $start);
	$sth->bind_param(3, $end);
	$sth->execute();
	
	my @departures;
	while (my $row = $sth->fetchrow_hashref) {
		push @departures, new WWW::IRail::API2::Departure(%$row);
	}
	return @departures;
}

sub get_earliest_departure {
	my ($self, $station) = @_;
	
	my $sth = $self->dbh()->prepare(<<END
SELECT direction, vehicle, delay, platform, time
FROM departures
WHERE station = ?
ORDER BY time ASC
LIMIT 1
END
	);
	
	$sth->bind_param(1, $station);
	$sth->execute();
	
	my $result = $sth->fetchrow_hashref;
	if ($result) {
		return new WWW::IRail::API2::Departure(%$result);
	} else {
		return undef;
	}
}

sub get_past_departures {
	my ($self, $station, $amount) = @_;
	
	my $sth = $self->dbh()->prepare(<<END
SELECT direction, vehicle, delay, platform, time
FROM departures
WHERE owner = ? AND time < ?
ORDER BY time desc
LIMIT ?
END
	);
	
	$sth->bind_param(1, $station);
	$sth->bind_param(2, time);
	$sth->bind_param(3, $amount);
	$sth->execute();
	
	my @departures;
	while (my $row = $sth->fetchrow_hashref) {
		push @departures, new WWW::IRail::API2::Departure(%$row);
	}
	return @departures;
}

sub get_past_departures_to {
	my ($self, $station, $direction, $amount) = @_;
	
	my $sth = $self->dbh()->prepare(<<END
SELECT vehicle, delay, platform, time
FROM departures
WHERE station = ? AND direction = ? AND time < strftime('%s')
ORDER BY time desc
LIMIT ?
END
	);
	
	$sth->bind_param(1, $station);
	$sth->bind_param(2, $direction);
	$sth->bind_param(3, time);
	$sth->bind_param(4, $amount);
	$sth->execute();
	
	my @departures;
	while (my $row = $sth->fetchrow_hashref) {
		push @departures, new WWW::IRail::API2::Departure(direction => $direction, %$row);
	}
	return @departures;
}

sub get_unique_destinations {
	my ($self, $station) = @_;
	
	my $sth = $self->dbh()->prepare(<<END
SELECT direction
FROM departures
WHERE station = ?
GROUP BY direction
END
	);
	
	$sth->bind_param(1, $station);
	$sth->execute();
	
	my $result = $sth->fetchall_arrayref;
	return map { $_->[0] } @$result;
}

sub get_past_departures_consecutively_delayed {
	my ($self, $station) = @_;
	
	my $sth = $self->dbh()->prepare(<<END
SELECT station, vehicle, delay, platform, time
FROM departures
WHERE station = ? AND time > (
	SELECT time
	FROM departures
	WHERE station = ? AND time < ? AND delay = 0
	ORDER BY time DESC
	LIMIT 1
) AND time <= ? AND delay > 0
END
	);
	
	$sth->bind_param(1, $station);
	$sth->bind_param(2, time);
	$sth->bind_param(3, $station);
	$sth->bind_param(4, time);
	$sth->execute();
	
	my @departures;
	while (my $row = $sth->fetchrow_hashref) {
		push @departures, new WWW::IRail::API2::Departure(%$row);
	}
	return @departures;
}

################################################################################
# Auxiliary
#

=pod

=head1 AUXILIARY

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
