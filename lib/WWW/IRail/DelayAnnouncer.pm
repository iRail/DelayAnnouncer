################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer;

# Packages
use Moose;
use File::Find;
use WWW::IRail::DelayAnnouncer::LiveboardUpdater;
use WWW::IRail::DelayAnnouncer::Database;
use WWW::IRail::DelayAnnouncer::Auxiliary qw/discover instantiate/;
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

has 'standalone' => (
	is		=> 'ro',
	isa		=> 'Bool',
	required	=> 1
);

has 'station' => (
	is		=> 'ro',
	isa		=> 'Str',
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
	default		=> 60
);

has 'liveboardupdater' => (
	is		=> 'ro',
	isa		=> 'WWW::IRail::DelayAnnouncer::LiveboardUpdater',
);

has 'database' => (
	is		=> 'ro',
	isa		=> 'WWW::IRail::DelayAnnouncer::Database',
	required	=> 1
);

has 'highscores' => (
	is		=> 'ro',
	isa		=> 'ArrayRef',
	builder		=> '_build_highscores'
);

sub _build_highscores {
	my %plugins = discover('WWW::IRail::DelayAnnouncer::Highscore')
		or LOGDIE "Error discovering highscore plugins: $!";
	my @objects = @{instantiate(\%plugins, undef)};
	return [grep { eval('$' . ref($_) . '::ENABLED || 0') }
		@objects];
}

has 'achievements' => (
	is		=> 'ro',
	isa		=> 'ArrayRef',
	builder		=> '_build_achievements'
);

sub _build_achievements {
	my %plugins = discover('WWW::IRail::DelayAnnouncer::Achievement')
		or LOGDIE "Error discovering achievement plugins: $!";
	my @objects = @{instantiate(\%plugins, undef)};
	return [grep { eval('$' . ref($_) . '::ENABLED || 0') }
		@objects];
}

has 'notifications' => (
	is		=> 'ro',
	isa		=> 'ArrayRef',
	builder		=> '_build_notifications'
);

sub _build_notifications {
	my %plugins = discover('WWW::IRail::DelayAnnouncer::Notification')
		or LOGDIE "Error discovering achievement plugins: $!";
	my @objects = @{instantiate(\%plugins, undef)};
	return [grep { eval('$' . ref($_) . '::ENABLED || 0') }
		@objects];
}


################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

sub BUILD {
	my ($self, $args) = @_;
	
	$self->{liveboardupdater} = new WWW::IRail::DelayAnnouncer::LiveboardUpdater(station => $self->station());
}

sub add_publisher {
	my ($self, $publisher) = @_;
	
	push @{$self->publishers()}, $publisher;
}

sub run {
	my ($self) = @_;
	
	DEBUG "Entering main loop";
	my %plugin_highscores;
	while (1) {
		DEBUG "Updating liveboard";
		$self->database()->add_liveboard($self->liveboardupdater()->update());
		my @messages;
		
		# Check highscores
		DEBUG "Checking highscores";
		foreach my $plugin (@{$self->highscores()}) {
			DEBUG "Processing " . ref($plugin);
			my $score = $plugin->calculate_score($self->database());
			next unless defined($score);
			
			if ($score > $self->database()->get_highscore($plugin->id())) {
				$plugin_highscores{$plugin->id()} = [ time, $plugin->message($self->station(), $score) ];
				$self->database()->set_highscore($plugin->id(), $score);
			}
			foreach my $plugin (keys %plugin_highscores) {
				my ($time, $message) = @{$plugin_highscores{$plugin}};
				if (time - $time > 600) {	# Wait for the highscore to settle
					push @messages, $message;
					delete $plugin_highscores{$plugin};
				} else {
					DEBUG "Not publishing a message of "
					. $plugin
					. " due to not settled ("
					. (time - $time)
					. " seconds passed since publish)";
				}
			}
			
			unless ($self->standalone()) {
				$self->database()->lock_global_highscore();
				my ($owner, $global_highscore) = $self->database()->get_global_highscore($plugin->id());
				if ($score > $global_highscore) {
					unless (defined $owner && $owner eq $self->station()) {
						push @messages, $plugin->global_message($self->station(), $owner, $score);
					}
					$self->database()->set_global_highscore($plugin->id(), $self->station(), $score);
				}
				$self->database()->unlock_global_highscore();
			}
		}
		
		# Check achievements
		DEBUG "Checking achievements";
		foreach my $plugin (@{$self->achievements()}) {
			DEBUG "Processing " . ref($plugin);
			$self->database()->init_achievement($plugin);
			my $plugin_messages = $plugin->messages($self->database());
			if (@$plugin_messages) {
				push @messages, @$plugin_messages;
				$self->database()->set_achievement_storage($plugin->id(), $plugin->storage());
			}
		}
		
		# Check notifications
		DEBUG "Checking notifications";
		foreach my $plugin (@{$self->notifications()}) {
			DEBUG "Processing " . ref($plugin);
			my $plugin_messages = $plugin->messages($self->database());
			# TODO: manage storage from here... but don't load too many fields within perl
			if (@$plugin_messages) {
				push @messages, @$plugin_messages;
			}			
		}
		
		# Publish messages
		if (scalar @messages > 0) {
			DEBUG "Publish messages";
			foreach my $message (@messages) {
				next unless (defined $message);
				foreach my $publisher (@{$self->{publishers}}) {
					$publisher->publish($message);
				}
			}
		}
		
		sleep($self->delay());
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