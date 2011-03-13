################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Database;

# Packages
use Moose;
use Log::Log4perl qw(:easy);
use DBIx::Log4perl;

# Write nicely
use strict;
use warnings;


################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=cut

has 'uri' => (
	is		=> 'ro',
	isa		=> 'Str',
	required	=> 1
);

has [qw/username password/] => (
	is		=> 'ro',
	isa		=> 'Str',
	default		=> ''
);

has 'prefix' => (
	is		=> 'ro',
	isa		=> 'Str',
	required	=> 1
);

has 'dbd' => (
	is		=> 'ro',
	isa		=> 'DBI::db',
	builder		=> '_build_dbd',
	lazy		=> 1
);

sub _build_dbd {
	my ($self) = @_;
	
	my $dbd = DBIx::Log4perl->connect($self->uri(), $self->username(), $self->password(), {
		RaiseError	=> 1,
		PrintError	=> 0,
		AutoCommit	=> 1
	});
	
	return $dbd;
}

has [qw(current_liveboard previous_liveboard)] => (
	is		=> 'ro',
	isa		=> 'WWW::IRail::DelayAnnouncer::Liveboard'
);


################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

sub BUILD {
	my ($self, $args) = @_;
	
	# Build lazy attributes
	$self->dbd();
}

sub create {
	my ($self) = @_;
	
	# Liveboard table
	my $sth = $self->dbd()->prepare(<<END
CREATE TABLE $self->{prefix}_liveboards (
	timestamp INTEGER,
	station TEXT,
	vehicle TEXT,
	delay INTEGER,
	platform INTEGER,
	time INTEGER
)	
END
	);
	$sth->execute();
	
	# Highscore table
	$sth = $self->dbd()->prepare(<<END
CREATE TABLE $self->{prefix}_highscores (
	id TEXT,
	timestamp INTEGER,
	score INTEGER,
	PRIMARY KEY(id(10))
)	
END
	);
	$sth->execute();
	
	# Achievement table
	$sth = $self->dbd()->prepare(<<END
CREATE TABLE $self->{prefix}_achievements (
	id TEXT,
	timestamp INTEGER,
	entry TEXT,
	value TEXT,
	PRIMARY KEY (id(10), entry(10))
)	
END
	);
	$sth->execute();
	
	# Notification table
	$sth = $self->dbd()->prepare(<<END
CREATE TABLE $self->{prefix}_notifications (
	id TEXT,
	timestamp INTEGER,
	station TEXT,
	time INTEGER,
	data TEXT,
	PRIMARY KEY (id(10), station(10), time)
)	
END
	);
	$sth->execute();
	
	# Trend table
	$sth = $self->dbd()->prepare(<<END
CREATE TABLE $self->{prefix}_trends (
	id TEXT,
	timestamp INTEGER,
	score INTEGER,
	high_time INTEGER,
	high_score INTEGER,
	PRIMARY KEY(id(10))
)	
END
	);
	$sth->execute();
}

sub create_shared {
	my ($self) = @_;
	
	# Highscore table
	my $sth = $self->dbd()->prepare(<<END
CREATE TABLE highscores (
	id TEXT,
	timestamp INTEGER,
	owner TEXT,
	score INTEGER,
	PRIMARY KEY(id(10))
)	
END
	);
	$sth->execute();
}

sub close {
	my ($self) = @_;
	
	DEBUG "Disconnecting database";
	$self->dbd()->disconnect()
		or WARN "Could not disconnect database: $DBI::errstr";
}

sub add_liveboard {
	my ($self, $liveboard) = @_;
	
	$self->{previous_liveboard} = $self->{current_liveboard};
	$self->{current_liveboard} = $liveboard;
	
	my $sth = $self->dbd()->prepare(<<END
INSERT INTO $self->{prefix}_liveboards (timestamp, station, vehicle, delay, platform, time)
VALUES (?, ?, ?, ?, ?, ?)
END
	);
	
	$sth->bind_param_array(1, $liveboard->timestamp());
	$sth->bind_param_array(2, [map { $_->{station} } @{$liveboard->departures()}]);
	$sth->bind_param_array(3, [map { $_->{vehicle} } @{$liveboard->departures()}]);
	$sth->bind_param_array(4, [map { $_->{delay} } @{$liveboard->departures()}]);
	$sth->bind_param_array(5, [map { $_->{platform} } @{$liveboard->departures()}]);
	$sth->bind_param_array(6, [map { $_->{time} } @{$liveboard->departures()}]);
	
	$sth->execute_array( {} );
}

sub get_highscore {
	my ($self, $plugin) = @_;
	
	my $sth = $self->dbd()->prepare(<<END
SELECT score
FROM $self->{prefix}_highscores
WHERE id = ?
END
	);
	
	$sth->bind_param(1, $plugin);	
	$sth->execute();
	
	my $result = $sth->fetchrow_arrayref;
	if ($result) {
		return @$result[0];
	} else {
		return 0;
	}	
}

sub set_highscore {
	my ($self, $plugin, $score) = @_;
	
	my $sth = $self->dbd()->prepare(<<END
REPLACE INTO $self->{prefix}_highscores
(id, timestamp, score)
VALUES (?, ?, ?)
END
	);
	
	$sth->bind_param(1, $plugin);
	$sth->bind_param(2, time);
	$sth->bind_param(3, $score);
	$sth->execute();
}

sub get_global_highscore {
	my ($self, $plugin) = @_;
	
	my $sth = $self->dbd()->prepare(<<END
SELECT owner, score
FROM highscores
WHERE id = ?
END
	);
	
	$sth->bind_param(1, $plugin);	
	$sth->execute();
	
	my $result = $sth->fetchrow_arrayref;
	if ($result) {
		return @$result;
	} else {
		return (undef, 0);
	}	
}

sub lock_global_highscore() {
	# TODO
}

sub unlock_global_highscore() {
	# TODO
}

sub set_global_highscore {
	my ($self, $plugin, $owner, $score) = @_;
	
	my $sth = $self->dbd()->prepare(<<END
REPLACE INTO highscores
(id, timestamp, owner, score)
VALUES (?, ?, ?, ?)
END
	);
	
	$sth->bind_param(1, $plugin);
	$sth->bind_param(2, time);
	$sth->bind_param(3, $owner);
	$sth->bind_param(4, $score);
	$sth->execute();
}

sub init_achievement {
	my ($self, $achievement) = @_;
	
	DEBUG "Checking " . $achievement->id();
	
	my $storage = $self->get_achievement_storage($achievement->id());
	if (keys %$storage) {
		$achievement->storage($storage);
	} else {
		$achievement->init_storage();
		$self->set_achievement_storage($achievement->id(), $achievement->storage());
	}
}

sub get_achievement_storage {
	my ($self, $plugin) = @_;
	
	my $sth = $self->dbd()->prepare(<<END
SELECT entry, value
FROM $self->{prefix}_achievements
WHERE id = ?
END
	);
	
	$sth->bind_param(1, $plugin);
	$sth->execute();
	
	my $result = $sth->fetchall_arrayref;
	my %storage = map { $_->[0] => $_->[1] }
		@{$result};
	return \%storage;
}

sub set_achievement_storage {
	my ($self, $plugin, $storage) = @_;
	
	my $sth = $self->dbd()->prepare(<<END
REPLACE INTO $self->{prefix}_achievements
(id, timestamp, entry, value)
VALUES (?, ?, ?, ?)
END
	);
	
	$sth->bind_param_array(1, $plugin);
	$sth->bind_param_array(2, time);
	$sth->bind_param_array(3, [ keys %{$storage} ]);
	$sth->bind_param_array(4, [ values %{$storage} ]);
	
	$sth->execute_array( {} );
	
}

sub get_notification_data {
	my ($self, $plugin, $station, $time) = @_;
	
	my $sth = $self->dbd()->prepare(<<END
SELECT data
FROM $self->{prefix}_notifications
WHERE id = ? AND station = ? AND time = ?
END
	);
	
	$sth->bind_param(1, $plugin);
	$sth->bind_param(2, $station);
	$sth->bind_param(3, $time);
	$sth->execute();
	
	my $result = $sth->fetchrow_arrayref;
	if ($result) {
		return $result->[0];
	} else {
		return undef;
	}
}

sub set_notification_data {
	my ($self, $plugin, $station, $time, $data) = @_;
	
	my $sth = $self->dbd()->prepare(<<END
REPLACE INTO $self->{prefix}_notifications
(id, timestamp, station, time, data)
VALUES (?, ?, ?, ?, ?)
END
	);
	
	$sth->bind_param(1, $plugin);
	$sth->bind_param(2, time);
	$sth->bind_param(3, $station);
	$sth->bind_param(4, $time);
	$sth->bind_param(5, $data);
	
	$sth->execute();
	
}

sub get_trend {
	my ($self, $plugin) = @_;
	
	my $sth = $self->dbd()->prepare(<<END
SELECT score, high_time, high_score
FROM $self->{prefix}_trends
WHERE id = ?
END
	);
	
	$sth->bind_param(1, $plugin);	
	$sth->execute();
	
	my $result = $sth->fetchrow_arrayref;
	if ($result) {
		return @$result;
	} else {
		return (0, 0, 0);
	}	
}

sub set_trend {
	my ($self, $plugin, $score, $high_time, $high_score) = @_;
	
	my $sth = $self->dbd()->prepare(<<END
REPLACE INTO $self->{prefix}_trends
(id, timestamp, score, high_time, high_score)
VALUES (?, ?, ?, ?, ?)
END
	);
	
	$sth->bind_param(1, $plugin);
	$sth->bind_param(2, time);
	$sth->bind_param(3, $score);
	$sth->bind_param(4, $high_time);
	$sth->bind_param(5, $high_score);
	$sth->execute();
}

sub get_departure_range {
	my ($self, $start, $end) = @_;	
	$end = time unless (defined $end);
	
	my $sth = $self->dbd()->prepare(<<END
SELECT max(station), vehicle, max(delay) AS maxdelay, max(platform), time
FROM $self->{prefix}_liveboards
WHERE timestamp BETWEEN ? AND ?
GROUP BY vehicle, time
END
	);
	
	$sth->bind_param(1, $start);
	$sth->bind_param(2, $end);
	$sth->execute();
	
	my $result = $sth->fetchall_arrayref;
	my @departures = map { _construct_departure(@{$_}) }
		@{$result};
	return @departures;
}

sub get_earliest_departure {
	my ($self) = @_;
	
	my $sth = $self->dbd()->prepare(<<END
SELECT station, vehicle, delay, platform, time
FROM $self->{prefix}_liveboards
ORDER BY timestamp ASC, time ASC
LIMIT 1
END
	);
	
	$sth->execute();
	
	my $result = $sth->fetchrow_arrayref;
	if ($result) {
		return _construct_departure(@{$result});
	} else {
		return undef;
	}
}

sub get_past_departures {
	my ($self, $amount) = @_;
	
	my $sth = $self->dbd()->prepare(<<END
SELECT max(station), vehicle, max(delay) AS maxdelay, max(platform), time
FROM $self->{prefix}_liveboards
WHERE time < ?
GROUP BY vehicle, time
ORDER BY time desc
LIMIT ?
END
	);
	
	$sth->bind_param(1, time);
	$sth->bind_param(2, $amount);
	$sth->execute();
	
	my $result = $sth->fetchall_arrayref;
	my @departures = map { _construct_departure(@{$_}) }
		@{$result};
	return @departures;	
}

sub get_past_departures_to {
	my ($self, $station, $amount) = @_;
	
	my $sth = $self->dbd()->prepare(<<END
SELECT vehicle, max(delay) AS maxdelay, max(platform), time
FROM $self->{prefix}_liveboards
WHERE station = ?
WHERE time < strftime('%s')
GROUP BY vehicle, time
ORDER BY time desc
LIMIT ?
END
	);
	
	$sth->bind_param(1, $station);
	$sth->bind_param(2, time);
	$sth->bind_param(3, $amount);
	$sth->execute();
	
	my $result = $sth->fetchall_arrayref;
	my @departures = map { _construct_departure($station, @{$_}) }
		@{$result};
	return @departures;
}

sub get_unique_destinations {
	my ($self) = @_;
	
	my $sth = $self->dbd()->prepare(<<END
SELECT station
FROM $self->{prefix}_liveboards
GROUP BY station
END
	);
	
	$sth->execute();
	
	my $result = $sth->fetchall_arrayref;
	return map { $_->[0] } @$result;
}

sub get_past_departures_consecutively_delayed {
	my ($self, $station, $amount) = @_;
	
	my $sth = $self->dbd()->prepare(<<END
SELECT max(station), vehicle, max(delay) AS maxdelay, max(platform), time
FROM $self->{prefix}_liveboards
WHERE time > (
	SELECT time
	FROM $self->{prefix}_liveboards
	WHERE time < ?
	GROUP BY vehicle, time
	HAVING max(delay) = 0
	ORDER BY time DESC
	LIMIT 1
) AND time <= ?
GROUP BY vehicle, time
HAVING max(delay) > 0
END
	);
	
	$sth->bind_param(1, time);
	$sth->bind_param(2, time);
	$sth->execute();
	
	my $result = $sth->fetchall_arrayref;
	my @departures = map { _construct_departure(@{$_}) }
		@{$result};
	return @departures;	
}

################################################################################
# Auxiliary
#

=pod

=head1 AUXILIARY

=cut

sub _construct_departure {
	return {
		station		=> $_[0],
		vehicle		=> $_[1],
		delay		=> $_[2],
		platform	=> $_[3],
		time		=> $_[4]
	};
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
