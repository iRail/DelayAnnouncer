################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer;

# Packages
use Moose;
use File::Find;
use WWW::IRail::DelayAnnouncer::Liveboard;
use WWW::IRail::DelayAnnouncer::Database;

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

has 'notifiers' => (
	is		=> 'rw',
	isa		=> 'ArrayRef[CodeRef]',
	default		=> sub { [] }
);

has 'delay' => (
	is		=> 'ro',
	isa		=> 'Int',
	default		=> 10
);

has 'liveboard' => (
	is		=> 'ro',
	isa		=> 'WWW::IRail::DelayAnnouncer::Liveboard',
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
	return _instantiate('WWW::IRail::DelayAnnouncer::Highscore');
}

has 'achievements' => (
	is		=> 'ro',
	isa		=> 'ArrayRef',
	builder		=> '_build_achievements'
);

sub _build_achievements {
	return _instantiate('WWW::IRail::DelayAnnouncer::Achievement');
}


################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

sub BUILD {
	my ($self, $args) = @_;
	
	$self->{liveboard} = new WWW::IRail::DelayAnnouncer::Liveboard(station => $self->station());
}

sub add_notifier {
	my ($self, $notifier) = @_;
	
	push @{$self->notifiers()}, $notifier;
}

sub run {
	my ($self) = @_;
	
	print "Entering main loop...\n";
	while (1) {
		$self->liveboard()->update();
		
		# Check highscores
		foreach my $plugin (@{$self->highscores()}) {
			my $score = $plugin->calculate_score($self->liveboard());
			if ($score > $self->database()->get_highscore($plugin->id())) {
				print $plugin->message($self->station(), $score);
				$self->database()->set_highscore($plugin->id(), $score);
			}
		}
		
		# Check achievements
		$self->database()->add_liveboard($self->liveboard());
		foreach my $plugin (@{$self->achievements()}) {
			$self->database()->init_achievement($plugin);
			if ($plugin->check($self->database())) {
				print $plugin->message();
				$self->database()->set_achievement_storage($plugin->id(), $plugin->storage());
			}
		}
		
		sleep($self->delay());
	}	
}


################################################################################
# Auxiliary
#

=pod

=head1 Auxiliary

=cut

sub _discover {
	my ($base) = @_;
	
	# Find the appropriate root folder
	my $subfolders = $base;
	$subfolders =~ s{::}{/}g;
	my $root;
	foreach my $directory (@INC) {
		my $pluginpath = "$directory/$subfolders";
		if (-d $pluginpath) {
			$root = $pluginpath;
			last;
		}
	}
	die("no inclusion directory matched plugin structure") unless defined $root;
	
	# Scan for Perl-modules
	my %plugins;
	find( sub {
		my $file = $File::Find::name;
		if ($file =~ m{$root/(.*)\.pm$}) {
			my $package = "$base/" . $1;
			$package =~ s{\/+}{::}g;
			$plugins{$package} = $file;
		}
	}, $root);
	
	return %plugins;
}

sub _instantiate {
	my ($base) = @_;
	
	# Discover all plugins
	my %plugins = _discover($base)
		or die("Error discovering plugins: $!");
	
	# Process all plugins
	my @plugins_usable;
	for my $package (sort keys %plugins) {
		my $file = $plugins{$package};
		
		# Load the plugin
		my $status = do $file;
		if (!$status) {
			if ($@) {
				warn("Error loading plugin $package: $@");
			}
			elsif ($!) {
				warn("Error loading plugin $package: $!");
			}
			else {
				warn("Error loading plugin $package: unknown failure");
			}
			next;
		}
		
		push @plugins_usable, new $package;
	}
	
	return \@plugins_usable;
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