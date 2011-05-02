################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer;

# Packages
use Moose;
use WWW::IRail::DelayAnnouncer::Storage;
use WWW::IRail::DelayAnnouncer::StationWorker;
use Log::Log4perl qw(:easy);

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

has 'stations' => (
	is		=> 'ro',
	isa		=> 'ArrayRef[Str]',
	required	=> 1
);

has 'workers' => (
	is		=> 'ro',
	isa		=> 'HashRef',
	lazy		=> 1,
	builder		=> '_build_workers'
);

sub _build_workers {
	my ($self) = @_;
	
	my %workers;
	foreach my $station (@{$self->stations}) {
		my $worker = new WWW::IRail::DelayAnnouncer::StationWorker(
			station			=> $station,
			announcer_storage	=> $self->announcer_storage,
			harvester_storage	=> $self->harvester_storage
		);
		$workers{$station} = $worker;
	}
	
	return \%workers;
}

has 'announcer_storage' => (
	is		=> 'ro',
	isa		=> 'WWW::IRail::DelayAnnouncer::Storage',
	lazy		=> 1,
	builder		=> '_build_announcer_storage'
);

sub _build_announcer_storage {
	my ($self) = @_;
	
	return new WWW::IRail::DelayAnnouncer::Storage(
		dbh	=> $self->dbh
	);
}

has 'harvester_storage' => (
	is		=> 'ro',
	isa		=> 'WWW::IRail::Harvester::Storage',
	required	=> 1
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
	$self->announcer_storage;
	$self->workers;
}

sub work {
	my ($self) = @_;
	
	foreach my $station (@{$self->stations}) {
		DEBUG "Activating worker for station " . $station;
		$self->workers->{$station}->work();
	}
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
