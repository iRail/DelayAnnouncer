################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::StationWorker;

# Packages
use Moose;
use File::Find;
use WWW::IRail::Harvester::Storage;
use WWW::IRail::DelayAnnouncer::Storage;
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

has 'station' => (
	is		=> 'ro',
	isa		=> 'Str',
	required	=> 1
);

has 'timestamp' => (
	is		=> 'rw',
	isa		=> 'Int',
	default		=> 0
);

has 'announcer_storage' => (
	is		=> 'ro',
	isa		=> 'WWW::IRail::DelayAnnouncer::Storage',
	required	=> 1
);

has 'harvester_storage' => (
	is		=> 'ro',
	isa		=> 'WWW::IRail::Harvester::Storage',
	required	=> 1
);

has 'highscores' => (
	is		=> 'ro',
	isa		=> 'ArrayRef',
	builder		=> '_build_highscores',
	lazy		=> 1
);

sub _build_highscores {
	my ($self) = @_;
	
	my %plugins = discover('WWW::IRail::DelayAnnouncer::Highscore::Station')
		or LOGDIE "Error discovering highscore plugins: $!";
	my @objects = @{instantiate(\%plugins, station => $self->station, storage => $self->harvester_storage)};
	return [grep { eval('$' . ref($_) . '::ENABLED || 0') }
		@objects];
}

has 'highscore_buffer' => (
	is		=> 'ro',
	isa		=> 'HashRef',
	default		=> sub { {} }
);

has 'achievements' => (
	is		=> 'ro',
	isa		=> 'ArrayRef',
	builder		=> '_build_achievements',
	lazy		=> 1
);

sub _build_achievements {
	my ($self) = @_;
	
	my %plugins = discover('WWW::IRail::DelayAnnouncer::Achievement::Station')
		or LOGDIE "Error discovering achievement plugins: $!";
	my @objects = @{instantiate(\%plugins, station => $self->station, storage => $self->harvester_storage)};
	return [grep { eval('$' . ref($_) . '::ENABLED || 0') }
		@objects];
}

has 'notifications' => (
	is		=> 'ro',
	isa		=> 'ArrayRef',
	builder		=> '_build_notifications',
	lazy		=> 1
);

sub _build_notifications {
	my ($self) = @_;
	
	my %plugins = discover('WWW::IRail::DelayAnnouncer::Notification::Station')
		or LOGDIE "Error discovering achievement plugins: $!";
	my @objects = @{instantiate(\%plugins, station => $self->station, storage => $self->harvester_storage, announcer_storage => $self->announcer_storage)};
	return [grep { eval('$' . ref($_) . '::ENABLED || 0') }
		@objects];
}

has 'trends' => (
	is		=> 'ro',
	isa		=> 'ArrayRef',
	builder		=> '_build_trends',
	lazy		=> 1
);

sub _build_trends {
	my ($self) = @_;
	
	my %plugins = discover('WWW::IRail::DelayAnnouncer::Trend::Station')
		or LOGDIE "Error discovering trend plugins: $!";
	my @objects = @{instantiate(\%plugins, station => $self->station, storage => $self->harvester_storage)};
	return [grep { eval('$' . ref($_) . '::ENABLED || 0') }
		@objects];
}

has 'publishers' => (
	is		=> 'ro',
	isa		=> 'ArrayRef',
	builder		=> '_build_publishers',
	lazy		=> 1
);

sub _build_publishers {
	my ($self) = @_;
	
	my %plugins = discover('WWW::IRail::DelayAnnouncer::Publisher::Station')
		or LOGDIE "Error discovering publisher plugins: $!";
	my @objects = @{instantiate(\%plugins, station => $self->station, storage => $self->harvester_storage)};
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
	my ($self) = @_;
	
	# Initialize lazy attributes
	$self->achievements;
	$self->notifications;
	$self->highscores;
	$self->trends;
	$self->publishers;
	
	# Initialize publisher settings
	foreach my $publisher (@{$self->publishers}) {
		$self->announcer_storage->init_publisher($publisher);
	}
}

sub work {
	my ($self) = @_;
	my @messages;
	
	# TODO: disconnect the stationworkers access to the database from the current liveboard. Everything through
	# queries! Maybe control the execution through  a "lastchanged" flag in the database.
	
	# Check if something has changed
	unless ($self->harvester_storage->current_liveboard($self->station)->timestamp > $self->timestamp) {
		return 0;
	}
	$self->timestamp($self->harvester_storage->current_liveboard($self->station)->timestamp);
	
	# Check highscores
	DEBUG "Checking highscores";
	foreach my $plugin (@{$self->highscores()}) {
		DEBUG "Processing " . ref($plugin);
		my $score = $plugin->calculate_score();
		next unless defined($score);
		DEBUG "Current score: $score";
		
		# Check hishscores
		my $highscore = $self->announcer_storage()->get_highscore($plugin);
		my ($global_owner, $global_highscore) = $self->announcer_storage()->get_global_highscore($plugin);
		DEBUG "Saved highscore: $highscore";
		if ($score > $highscore) {
			DEBUG "Highscore topped with a score of $score";
			$self->highscore_buffer->{$plugin->id()} = [ time, $plugin->message($score) ];
			
			if ($score > $global_highscore) {
				DEBUG "Global highscore topped with a score of $score";
				unless (defined $global_owner && $global_owner eq $self->station()) {
					# Force a publish of a queue'd highscore message as well
					my ($time, $message) = @{$self->highscore_buffer->{$plugin->id()}};
					push @messages, $message;
					delete $self->highscore_buffer->{$plugin->id()};
					
					push @messages, $plugin->global_message($global_owner, $score);
				}							
			}
			
			$self->announcer_storage()->set_highscore($plugin, $score);
		}
	}
	foreach my $plugin (keys %{$self->highscore_buffer}) {
		my ($time, $message) = @{$self->highscore_buffer->{$plugin}};
		if (time - $time > 3600) {	# Wait for the highscore to settle
			push @messages, $message;
			delete $self->highscore_buffer->{$plugin};
		} else {
			DEBUG "Not yet publishing a message of "
			. $plugin
			. " due to not settled ("
			. (time - $time)
			. " seconds passed since publish)";
		}
	}			
	
	# Check achievements
	DEBUG "Checking achievements";
	foreach my $plugin (@{$self->achievements()}) {
		DEBUG "Processing " . ref($plugin);
		$self->announcer_storage()->init_achievement($plugin);
		my $plugin_messages = $plugin->messages();
		if (@$plugin_messages) {
			push @messages, @$plugin_messages;
			$self->announcer_storage()->set_achievement_bag($plugin);
		}
	}
	
	# Check notifications
	DEBUG "Checking notifications";
	foreach my $plugin (@{$self->notifications()}) {
		DEBUG "Processing " . ref($plugin);
		my $plugin_messages = $plugin->messages();
		# TODO: manage storage from here... but don't load too many fields within perl
		if (@$plugin_messages) {
			push @messages, @$plugin_messages;
		}			
	}
	
	# Check trends
	DEBUG "Checking trends";
	foreach my $plugin (@{$self->trends()}) {
		DEBUG "Processing " . ref($plugin);
		my $score = $plugin->calculate_score();				
		next unless defined($score);
		DEBUG "Current trend value: $score";
		
		# Check score
		my ($previous, $high_time, $high_score) = $self->announcer_storage()->get_trend($plugin);
		DEBUG "Previous trend value: $previous";
		DEBUG "High trend value: $high_score (hit " . (time-$high_time) . " seconds ago)";				
		if ($score > $previous) {
			DEBUG "Trend value increased";
			# Check trend
			if ($score > $high_score || (time-$high_time) > $plugin->expiry()) {
				DEBUG "Trend highscore breached or expired, publishing message";
				push @messages, $plugin->message($score);
				$high_time = time;
				$high_score = $score;
			} else {
				DEBUG "Trend value didn't increase highscore, which hasn't expired yet";
			}
		}
		$self->announcer_storage()->set_trend($plugin, $score, $high_time, $high_score);
	}
	
	# Publish messages
	if (scalar @messages > 0) {		
		DEBUG "Publish messages";
		foreach my $message (@messages) {
			next unless (defined $message);
			foreach my $publisher (@{$self->publishers}) {
				$publisher->publish($message);
			}
		}
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
