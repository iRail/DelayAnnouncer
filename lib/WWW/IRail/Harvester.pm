################################################################################
# Configuration
#

# Package definition
package WWW::IRail::Harvester;

# Packages
use Moose;
use WWW::IRail::Harvester::Storage;
use WWW::IRail::API2;
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

has 'api' => (
	is		=> 'ro',
	isa		=> 'WWW::IRail::API2',
	default		=> sub { new WWW::IRail::API2 }
);

has 'stations' => (
	is		=> 'ro',
	isa		=> 'ArrayRef[Str]',
	required	=> 1
);

has 'publishers' => (
	is		=> 'rw',
	isa		=> 'ArrayRef',
	default		=> sub { [] }
);

has 'delay' => (
	is		=> 'ro',
	isa		=> 'Int',
	default		=> 120
);

has 'storage' => (
	is		=> 'ro',
	isa		=> 'WWW::IRail::Harvester::Storage',
	builder		=> '_build_storage',
	lazy		=> 1
);

sub _build_storage {
	my ($self) = @_;
	
	return new WWW::IRail::Harvester::Storage(
		dbh	=> $self->dbh
	);
}


################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

sub BUILD {
	my ($self) = @_;
	
	# Build lazy attributes
	$self->storage;
	
	# Fetch the station list
	my $stations = $self->api->stations() || die("Could not fetch station list");
	$self->storage->set_stations(@$stations);
	
	# Process the magic "all" value
	if (scalar @{$self->stations} == 1 && $self->stations->[0] eq "all") {
		$self->{stations} = [map { $_->id } @$stations];
	}
}

sub work {
	my ($self) = @_;
	
	foreach my $station (@{$self->stations}) {
		DEBUG "Harvesting liveboard for station " . $station;
		my $liveboard = new WWW::IRail::API2::Liveboard(station => $station);
		
		for (my $i = 0; $i < @{$liveboard->departures}; $i++) {
			my $id = $liveboard->departures->[$i]->direction;
			unless (grep { $_->id eq $id } @{$self->storage->get_stations}) {
				WARN "Dropping departure to unknown station $id";
				splice @{$liveboard->departures}, $i--, 1;
			}
		}
		$self->storage->add_liveboard($liveboard);
		my @messages;
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
