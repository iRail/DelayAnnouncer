################################################################################
# Configuration
#

# Package definition
package WWW::IRail::DelayAnnouncer::Auxiliary;

# Packages
use File::Find;
use Log::Log4perl qw(:easy);

# Export
use base 'Exporter';
our @EXPORT = ('discover', 'instantiate', 'instantiate_easy');

# Write nicely
use strict;
use warnings;


################################################################################
# Methods
#

=pod

=head1 Methods

=cut

sub discover {
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
	LOGDIE "no inclusion directory matched plugin structure"
		unless defined $root;
	
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

sub instantiate_easy {
	my ($base) = @_;
	
	# Discover all plugins
	my %plugins = discover($base)
		or LOGDIE "Error discovering plugins: $!";
	
	# Instantiage the plugins
	return instantiate(\%plugins, undef);
}

sub instantiate {
	my ($plugins, $arguments) = @_;
	
	# Process all plugins
	my @plugins_usable;
	for my $package (sort keys %$plugins) {
		my $file = $plugins->{$package};
		
		# Load the plugin
		my $status = do $file;
		if (!$status) {
			if ($@) {
				WARN "Error loading plugin $package: $@";
			}
			elsif ($!) {
				WARN "Error loading plugin $package: $!";
			}
			else {
				WARN "Error loading plugin $package: unknown failure";
			}
			next;
		}
		
		if (defined $arguments && defined $arguments->{$package}) {
			my $argument = $arguments->{$package};
			push @plugins_usable, new $package($argument) if (ref($argument) eq "");
			push @plugins_usable, new $package($$argument) if (ref($argument) eq "SCALAR");
			push @plugins_usable, new $package(@{$argument}) if (ref($argument) eq "ARRAY");
			push @plugins_usable, new $package(%{$argument}) if (ref($argument) eq "HASH");
			push @plugins_usable, new $package(&$argument) if (ref($argument) eq "CODE");
		} else {
			push @plugins_usable, new $package;
		}
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