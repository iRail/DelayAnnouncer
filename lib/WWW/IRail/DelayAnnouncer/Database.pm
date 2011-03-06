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
	
	my $dbd = DBIx::Log4perl->connect($self->uri(), '', '', {
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
CREATE TABLE $self->{prefix}_liveboard (
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
	id TEXT PRIMARY KEY,
	timestamp INTEGER,
	score INTEGER	
)	
END
	);
	$sth->execute();
	
	# Achievement table
	$sth = $self->dbd()->prepare(<<END
CREATE TABLE $self->{prefix}_achievements (
	id,
	timestamp INTEGER,
	key TEXT,
	value TEXT,
	PRIMARY KEY (id, key)
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
	id TEXT PRIMARY KEY,
	timestamp INTEGER,
	owner TEXT,
	score INTEGER	
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
INSERT INTO $self->{prefix}_liveboard (timestamp, station, vehicle, delay, platform, time)
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
WHERE id == ?
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
INSERT OR REPLACE
INTO $self->{prefix}_highscores
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
WHERE id == ?
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
INSERT OR REPLACE
INTO highscores
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
SELECT key, value
FROM $self->{prefix}_achievements
WHERE id == ?
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
INSERT OR REPLACE
INTO $self->{prefix}_achievements
(id, timestamp, key, value)
VALUES (?, ?, ?, ?)
END
	);
	
	$sth->bind_param_array(1, $plugin);
	$sth->bind_param_array(2, time);
	$sth->bind_param_array(3, [ keys %{$storage} ]);
	$sth->bind_param_array(4, [ values %{$storage} ]);
	
	$sth->execute_array( {} );
	
}

sub get_liveboard_range {
	my ($self, $start, $end) = @_;	
	$end = time unless (defined $end);
	
	my $sth = $self->dbd()->prepare(<<END
SELECT max(timestamp), max(station), vehicle, max(delay) AS maxdelay, max(platform), time
FROM $self->{prefix}_liveboard
WHERE timestamp BETWEEN ?  AND ?
GROUP BY vehicle, time
END
	);
	
	$sth->bind_param(1, $start);
	$sth->bind_param(2, $end);
	$sth->execute();
	
	my $result = $sth->fetchall_arrayref;
	my @liveboards = map { _construct_liveboard(@_) }
		@{$result};
	return @liveboards;
}

sub get_earliest_liveboard {
	my ($self) = @_;
	
	my $sth = $self->dbd()->prepare(<<END
SELECT *
FROM $self->{prefix}_liveboard
ORDER BY timestamp
LIMIT 1
END
	);
	
	$sth->execute();
	
	my $result = $sth->fetchrow_arrayref;
	if ($result) {
		return _construct_liveboard($result->[0]);
	} else {
		return undef;
	}
}


################################################################################
# Auxiliary
#

=pod

=head1 AUXILIARY

=cut

sub _construct_liveboard {	
	return new Liveboard(
				timestamp	=> $_[0],
				station		=> $_[1],
				vehicle		=> $_[2],
				delay		=> $_[3],
				platform	=> $_[4],
				time		=> $_[5]
			);
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