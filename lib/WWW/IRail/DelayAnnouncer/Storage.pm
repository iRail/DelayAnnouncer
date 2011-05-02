################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Storage;

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

has 'dbh' => (
	is		=> 'ro',
	isa		=> 'DBI::db',
	required	=> 1
);


################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

sub BUILD {
	my ($self) = @_;	
	
	# Highscore table
	my $sth = $self->dbh()->prepare(<<END
CREATE TABLE IF NOT EXISTS highscores (
	owner varchar(40) NOT NULL,
	id varchar(20) NOT NULL,
	timestamp int(11) NOT NULL,
	score int(11) DEFAULT NULL,
	PRIMARY KEY(owner,id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8	
END
	);
	$sth->execute();
	
	# Achievement table
	$sth = $self->dbh()->prepare(<<END
CREATE TABLE IF NOT EXISTS achievements (
	owner varchar(40) NOT NULL,
	id varchar(20) NOT NULL,
	timestamp int(11) NOT NULL,
	entry varchar(40) NOT NULL,
	value varchar(100) DEFAULT NULL,
	PRIMARY KEY (owner,id,entry)
) ENGINE=InnoDB DEFAULT CHARSET=utf8	
END
	);
	$sth->execute();
	
	# Notification table
	$sth = $self->dbh()->prepare(<<END
CREATE TABLE IF NOT EXISTS notifications (
	owner varchar(40) NOT NULL,
	id varchar(20) NOT NULL,
	timestamp int(11) NOT NULL,
	direction TEXT,
	time INTEGER,
	data TEXT,
	PRIMARY KEY (owner,id,time)
)	
END
	);
	$sth->execute();
	
	# Trend table
	$sth = $self->dbh()->prepare(<<END
CREATE TABLE IF NOT EXISTS trends (
	owner varchar(40) NOT NULL,
	id varchar(20) NOT NULL,
	timestamp int(11) NOT NULL,
	score int(11),
	high_time int(11),
	high_score int(11),
	PRIMARY KEY(owner,id)
)	
END
	);
	$sth->execute();
	
	# Publisher table
	$sth = $self->dbh()->prepare(<<END
CREATE TABLE IF NOT EXISTS publishers (
	owner varchar(40) NOT NULL,
	id varchar(20) NOT NULL,
	entry varchar(40) NOT NULL,
	value varchar(100) DEFAULT NULL,
	PRIMARY KEY (owner,id,entry)
) ENGINE=InnoDB DEFAULT CHARSET=utf8	
END
	);
	$sth->execute();
}

sub get_highscore {
	my ($self, $owner, $plugin) = @_;
	
	my $sth = $self->dbh()->prepare(<<END
SELECT score
FROM highscores
WHERE owner = ? AND id = ?
END
	);
	
	$sth->bind_param(1, $owner);
	$sth->bind_param(2, $plugin);
	$sth->execute();
	
	my $result = $sth->fetchrow_arrayref;
	if ($result) {
		return @$result[0];
	} else {
		return 0;
	}	
}

sub set_highscore {
	my ($self, $owner, $plugin, $score) = @_;
	
	my $sth = $self->dbh()->prepare(<<END
REPLACE INTO highscores
(owner, id, timestamp, score)
VALUES (?, ?, ?, ?)
END
	);
	
	$sth->bind_param(1, $owner);
	$sth->bind_param(2, $plugin);
	$sth->bind_param(3, time);
	$sth->bind_param(4, $score);
	$sth->execute();
}

sub get_global_highscore {
	my ($self, $plugin) = @_;
	
	my $sth = $self->dbh()->prepare(<<END
SELECT owner, score
FROM highscores
WHERE id = ? AND score = (
	SELECT MAX(score)
	FROM highscores
	WHERE id = ?
)
END
	);
	
	$sth->bind_param(1, $plugin);
	$sth->bind_param(2, $plugin);
	$sth->execute();
	
	my $result = $sth->fetchrow_arrayref;
	if ($result) {
		return @$result;
	} else {
		return (undef, 0);
	}	
}

sub init_achievement {
	my ($self, $owner, $achievement) = @_;
	
	DEBUG "Checking " . $achievement->id();
	
	my $bag = $self->get_achievement_bag($owner, $achievement->id());
	if (keys %$bag) {
		$achievement->bag($bag);
	} else {
		$achievement->init_bag();
		$self->set_achievement_bag($owner, $achievement->id(), $achievement->bag());
	}
}

sub get_achievement_bag {
	my ($self, $owner, $plugin) = @_;
	
	my $sth = $self->dbh()->prepare(<<END
SELECT entry, value
FROM achievements
WHERE owner = ? AND id = ?
END
	);
	
	$sth->bind_param(1, $owner);
	$sth->bind_param(2, $plugin);
	$sth->execute();
	
	my $result = $sth->fetchall_arrayref;
	my %bag = map { $_->[0] => $_->[1] }
		@{$result};
	return \%bag;
}

sub set_achievement_bag {
	my ($self, $owner, $plugin, $bag) = @_;
	
	my $sth = $self->dbh()->prepare(<<END
REPLACE INTO achievements
(owner, id, timestamp, entry, value)
VALUES (?, ?, ?, ?, ?)
END
	);
	
	$sth->bind_param_array(1, $owner);
	$sth->bind_param_array(2, $plugin);
	$sth->bind_param_array(3, time);
	$sth->bind_param_array(4, [ keys %{$bag} ]);
	$sth->bind_param_array(5, [ values %{$bag} ]);
	
	$sth->execute_array( {} );	
}

sub get_notification_data {
	my ($self, $owner, $plugin, $station, $time) = @_;
	
	my $sth = $self->dbh()->prepare(<<END
SELECT data
FROM notifications
WHERE owner = ? AND id = ? AND station = ? AND time = ?
END
	);
	
	$sth->bind_param(1, $owner);
	$sth->bind_param(2, $plugin);
	$sth->bind_param(3, $station);
	$sth->bind_param(4, $time);
	$sth->execute();
	
	my $result = $sth->fetchrow_arrayref;
	if ($result) {
		return $result->[0];
	} else {
		return undef;
	}
}

sub set_notification_data {
	my ($self, $owner, $plugin, $station, $time, $data) = @_;
	
	my $sth = $self->dbh()->prepare(<<END
REPLACE INTO notifications
(owner, id, timestamp, station, time, data)
VALUES (?, ?, ?, ?, ?, ?)
END
	);
	
	$sth->bind_param(1, $owner);
	$sth->bind_param(2, $plugin);
	$sth->bind_param(3, time);
	$sth->bind_param(4, $station);
	$sth->bind_param(5, $time);
	$sth->bind_param(6, $data);
	
	$sth->execute();
	
}

sub get_trend {
	my ($self, $owner, $plugin) = @_;
	
	my $sth = $self->dbh()->prepare(<<END
SELECT score, high_time, high_score
FROM trends
WHERE owner = ? AND id = ?
END
	);
	
	$sth->bind_param(1, $owner);
	$sth->bind_param(2, $plugin);
	$sth->execute();
	
	my $result = $sth->fetchrow_arrayref;
	if ($result) {
		return @$result;
	} else {
		return (0, 0, 0);
	}	
}

sub set_trend {
	my ($self, $owner, $plugin, $score, $high_time, $high_score) = @_;
	
	my $sth = $self->dbh()->prepare(<<END
REPLACE INTO trends
(owner, id, timestamp, score, high_time, high_score)
VALUES (?, ?, ?, ?, ?, ?)
END
	);
	
	$sth->bind_param(1, $owner);
	$sth->bind_param(2, $plugin);
	$sth->bind_param(3, time);
	$sth->bind_param(4, $score);
	$sth->bind_param(5, $high_time);
	$sth->bind_param(6, $high_score);
	$sth->execute();
}


sub init_publisher {
	my ($self, $owner, $publisher) = @_;
	
	DEBUG "Checking " . $publisher->id();
	
	my $settings = $self->get_publisher_settings($owner, $publisher->id());
	if (keys %$settings) {
		$publisher->settings($settings);
	} else {
		$publisher->init_settings();
		$self->set_publisher_settings($owner, $publisher->id(), $publisher->settings());
	}
}

sub get_publisher_settings {
	my ($self, $owner, $plugin) = @_;
	
	my $sth = $self->dbh()->prepare(<<END
SELECT entry, value
FROM publishers
WHERE owner = ? AND id = ?
END
	);
	
	$sth->bind_param(1, $owner);
	$sth->bind_param(2, $plugin);
	$sth->execute();
	
	my $result = $sth->fetchall_arrayref;
	my %bag = map { $_->[0] => $_->[1] }
		@{$result};
	return \%bag;
}

sub set_publisher_settings {
	my ($self, $owner, $plugin, $settings) = @_;
	
	my $sth = $self->dbh()->prepare(<<END
REPLACE INTO publishers
(owner, id, entry, value)
VALUES (?, ?, ?, ?)
END
	);
	
	$sth->bind_param_array(1, $owner);
	$sth->bind_param_array(2, $plugin);
	$sth->bind_param_array(3, [ keys %{$settings} ]);
	$sth->bind_param_array(4, [ values %{$settings} ]);
	
	$sth->execute_array( {} );	
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
