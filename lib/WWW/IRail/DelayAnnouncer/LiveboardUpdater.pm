################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::LiveboardUpdater;

# Packages
use Moose;
use JSON;
use LWP::UserAgent;
use URI::Escape ('uri_escape');
use Log::Log4perl qw(:easy);
use WWW::IRail::DelayAnnouncer::Liveboard;

# Write nicely
use strict;
use warnings;


################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=cut

has 'station' => (
	is		=> 'ro',
	isa		=> 'Str',
	required	=> 1
);

has 'url' => (
	is		=> 'ro',
	isa		=> 'String'
);

has 'json' => (
	is		=> 'ro',
	isa		=> 'JSON',
	default		=> sub { new JSON }
);

has 'ua' => (
	is		=> 'ro',
	isa		=> 'LWP::UserAgent',
	default		=> sub { new LWP::UserAgent(agent => 'irail-delayannouner') }
);



################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

sub BUILD {
	my ($self, $args) = @_;
	
	$self->{url} = 'http://api.irail.be/liveboard.php?station='
		.uri_escape($self->station())
		.'&format=json';
}

sub update {
	my ($self) = @_;
	
	my $response = $self->ua()->get($self->url());
	LOGDIE "Could not fetch liveboard data"
		unless($response->is_success);
	
	# TODO: dit mag niet crashen, gwn niet verer processen dan en aan dlay announcer laten weten
	my $data = $self->json()->decode($response->decoded_content);
	
	my $timestamp = $data->{timestamp};
	my $departures;
	if ($data->{departures}->{number} == 1) {				# WORKAROUND
		$departures = [ $data->{departures}{departure} ];		# WORKAROUND
	} else {								# WORKAROUND
		$departures = $data->{departures}{departure};
	}
	
	foreach my $departure (@{$departures}) {
		my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($departure->{time});
		DEBUG "Departure at "
			. sprintf("%02i:%02i", $hour, $min)
			. " to " . $departure->{station}
			. ", on platform "
			. $departure->{platform};
		if ($departure->{platform} eq "NA") {
			$departure->{platform} = undef;
		}
	}
	
	
	DEBUG "Updated liveboard";
	return new WWW::IRail::DelayAnnouncer::Liveboard(
		timestamp	=> $timestamp,
		departures	=> $departures
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