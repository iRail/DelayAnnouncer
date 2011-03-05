################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Publisher::Twitter;

# Packages
use Moose;
use Net::Twitter;
use Log::Log4perl qw(:easy);

# Write nicely
use strict;
use warnings;

# Roles
with 'WWW::IRail::DelayAnnouncer::Publisher';


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
	    traits              => [qw/API::REST OAuth/],
	    consumer_key        => $self->consumer_key,
	    consumer_secret     => $self->consumer_secret
	);
	
	return $nt;
};

has [qw/consumer_key consumer_secret/] => (
	is		=> 'ro',
	isa		=> 'Str',
	required	=> 1
);

has [qw/access_token access_token_secret/] => (
	is		=> 'ro',
	isa		=> 'Str',
);

has [qw/latitude longitude/] => (
	is		=> 'ro',
	isa		=> 'Num',
	required	=> 1
);

has 'suffix_url' => (
	is		=> 'ro',
	isa		=> 'Str'
);


################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

sub BUILD {
	my ($self) = @_;
	
	# Build lazy attributes
	$self->twitter();
	
	if (defined $self->consumer_key() && defined $self->consumer_secret()
		&& (!defined $self->access_token() || !defined $self->access_token_secret())) {
	    INFO "Authorize at ", $self->twitter()->get_authorization_url, " and enter the PIN number";
	    my $pin = <STDIN>; # wait for input
	    chomp $pin;

	    my ($access_token, $access_token_secret, $user_id, $screen_name) = $self->twitter()->request_access_token(verifier => $pin);
	    INFO "Now update your configuration with:";
	    INFO "  access_token = $access_token";
	    INFO "  access_token_secret = $access_token_secret";
	    
	    LOGDIE "Twitter access tokens not found";
	}
	
	# Configure access token
	$self->twitter()->access_token($self->access_token());
	$self->twitter()->access_token_secret($self->access_token_secret());
	
	unless ($self->twitter()->authorized) {
	    LOGDIE "Twitter publisher not authorized, please verify your configuration";
	}
}

sub publish {
	my ($self, $message) = @_;
	
	if (defined $self->{suffix_url}) {
		$message .= " " . $self->{suffix_url};
	}
	
	$self->twitter()->update({
		status                  => $message,
		long                    => $self->longitude(),
		lat                     => $self->latitude(),
		display_coordinates     => 1
	});
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