################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Publisher::Station::Twitter;

# Packages
use Moose;
use Net::Twitter;
use Log::Log4perl qw(:easy);
use WWW::Shorten::Googl;

# Write nicely
use strict;
use warnings;

# Roles
with 'WWW::IRail::DelayAnnouncer::Publisher::Station';

# Package information
our $ENABLED = 1;


################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=cut

has 'twitter' => (
	is		=> 'ro',
	isa		=> 'Net::Twitter',
	builder		=> '_build_twitter',
	lazy		=> 1
);

sub _build_twitter {
	my ($self) = @_;
	
	my $nt = Net::Twitter->new(
		traits			=> [qw/API::REST OAuth/],
		consumer_key		=> $self->settings->{consumer_key},
		consumer_secret		=> $self->settings->{consumer_secret},
		access_token		=> $self->settings->{access_token},
		access_token_secret	=> $self->settings->{access_token_secret}
	);
	
	unless ($nt->authorized) {
	    LOGDIE "Twitter publisher not authorized, please verify your configuration";
	}
	
	return $nt;
};


################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

sub init_settings {
	my ($self) = @_;
	
	INFO "Insert the consumer key for station " . $self->stationname;
	chomp(my $consumer_key = <STDIN>);
	
	INFO "Insert the consumer secret for station " . $self->stationname;
	chomp(my $consumer_secret = <STDIN>);
	
	my $nt = Net::Twitter->new(
	    traits              => [qw/API::REST OAuth/],
	    consumer_key        => $consumer_key,
	    consumer_secret     => $consumer_secret
	);
	
	INFO "Authorize at ", $nt->get_authorization_url, " and enter the PIN number";
	chomp(my $pin = <STDIN>);
	
	my ($access_token, $access_token_secret, $user_id, $screen_name) = $nt->request_access_token(verifier => $pin);
	unless ($nt->authorized) {
	    LOGDIE "Twitter publisher not authorized, please verify your configuration";
	}
	INFO "Configured for Twitter account " . $screen_name;
	
	my $station_data = (grep { $_->id eq $self->station } @{$self->storage->get_stations()})[0];
	my ($url, $longitude, $latitude);
	if (defined $station_data) {
		my $url_long = 'http://liveboards.irail.be/liveboard.html?station=' . $station_data->name;
		$url = makeashorterlink($url_long);
		
		$longitude = $station_data->longitude;
		$latitude = $station_data->latitude;
	}
	
	my $hashtag = 'StationBattle';
	
	$self->settings({
		consumer_key		=> $consumer_key,
		consumer_secret		=> $consumer_secret,
		access_token		=> $access_token,
		access_token_secret	=> $access_token_secret,
		url			=> $url,
		hashtag			=> $hashtag,
		longitude		=> $longitude,
		latitude		=> $latitude
	});
}

sub publish {
	my ($self, $message) = @_;
	
	if (defined $self->settings->{url}) {
		$message .= ' ' . $self->settings->{url};
	}
	
	if (defined $self->settings->{hashtag}) {
		$message .= ' #' . $self->settings->{hashtag};
	}
	
	eval {
		if (defined $self->settings->{latitude} && defined $self->settings->{longitude}) {
			$self->twitter()->update({
				status                  => $message,
				long                    => $self->settings->{longitude},
				lat                     => $self->settings->{latitude},
				display_coordinates     => 1
			});
		} else {
			$self->twitter()->update({
				status                  => $message
			});		
		}
	};
	if ($@) {
		WARN "Tweeting message failed";
		WARN $@;
		return undef;
	}
	return 1;
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
