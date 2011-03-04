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
CREATE TABLE liveboard (
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
CREATE TABLE highscores (
	id TEXT PRIMARY KEY,
	timestamp INTEGER,
	score INTEGER	
)	
END
	);
	$sth->execute();
	
	# Achievement table
	$sth = $self->dbd()->prepare(<<END
CREATE TABLE achievements (
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

sub close {
	my ($self) = @_;
	
	DEBUG "Disconnecting database";
	$self->dbd()->disconnect()
		or WARN "Could not disconnect database: $DBI::errstr";
}

sub add_liveboard {
	my ($self, $liveboard) = @_;
	
	$self->{previous_liveboard} = $self->{current_liveboard};
	$self->{current_liveboard} = $liveboard->clone_data();
	
	my $sth = $self->dbd()->prepare(<<END
INSERT INTO liveboard (timestamp, station, vehicle, delay, platform, time)
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
FROM highscores
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
INTO highscores
(id, timestamp, score)
VALUES (?, ?, ?)
END
	);
	
	$sth->bind_param(1, $plugin);
	$sth->bind_param(2, time);
	$sth->bind_param(3, $score);
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
FROM achievements
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
INTO achievements
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