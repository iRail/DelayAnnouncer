#!/usr/bin/env perl
#
# iRail delay announcer
#
# Copyright (c) 2011 Tim Besard
#
# This file is part of the iRail delay announcer, an set of open-source Perl
# scripts, leveraging the iRail API to generate messages announcing the delay
# status of certain stations.
# 
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# Authors:
#    Tim Besard <tim-dot-besard-at-gmail-dot-com>
#

###############################################################################
# Configuration
#

#
# Modules
#

# Write nicely
use strict;
use warnings;

# Packages
use Config::Tiny;
use Getopt::Long;
use Pod::Usage;
use WWW::IRail::DelayAnnouncer;
use WWW::IRail::Harvester;
use DBIx::Log4perl;
use Log::Log4perl qw(:easy);

# Initial logging
Log::Log4perl->easy_init($INFO);

# Signal handling
$SIG{INT} = "quit";
$SIG{TERM} = "quit";


###############################################################################
# Initialization
#

#
# Load command-line parameters
#

INFO "Initialising";
DEBUG "Loading command-line parameters";

# Register variables
my %params;
$params{config} = "announcer.ini";

# Load
GetOptions(
    \%params,
    "config|c=s",
    "help|h",
    "man"
);

# Actions
if ($params{"man"}) {
	pod2usage(-verbose => 2);
	exit(0);
} elsif ($params{"help"}) {
	pod2usage(-verbose => 1);
	exit(0);
}


#
# Load configuration
#

DEBUG "Loading configuration";

# Read config
my $config = Config::Tiny->read($params{config})
    or LOGDIE "Could not read the configuration file at $params{config}: $!";

# Create some section objects
my $config_root = delete $config->{_} || {};
my $config_harvester = delete $config->{harvester} || {};
my $config_announcer = delete $config->{announcer} || {};
my $config_log = delete $config->{log}
    or LOGDIE "Log configuration section missing";
my $config_database = delete $config->{database}
    or LOGDIE "Database configuration section missing";


#
# Check root configuration
#

LOGDIE "Please specify a delay value"
    unless (defined $config_root->{delay});
LOGDIE "Please specify a stationlist"
    unless (defined $config_root->{stations});

# Process the stationlist
my @stationlist = split(/,/, $config_root->{stations});


#
# Load logging
#

DEBUG "Loading logging";

# Check configuration
LOGDIE "Please specify a logging type"
    unless (defined $config_log->{type});

# Configure Log4perl
if ($config_log->{type} eq "easy") {
    LOGDIE "Easy logging type requires a logging level"
        unless (defined $config_log->{level});
    my %levels = (
        trace   => $TRACE,
        debug   => $DEBUG,
        info    => $INFO,
        warn    => $WARN,
        error   => $ERROR,
        fatal   => $FATAL
    );
    LOGDIE "Invalid logging level"
        unless defined($levels{$config_log->{level}});
    Log::Log4perl->easy_init($levels{$config_log->{level}});
} elsif ($config_log->{type} eq "enhanced") {
    LOGDIE "Easy logging type requires a log configuration file"
        unless (defined $config_log->{file});
    Log::Log4perl::init($config_log->{file});    
} else {
    LOGDIE "Invalid logging type";
}

# Handle regular warn()
$SIG{__WARN__} = sub {
    local $Log::Log4perl::caller_depth =
        $Log::Log4perl::caller_depth + 1;
    WARN @_;
};

# Handle regular die()
$SIG{__DIE__} = sub {
    # Don't trap eval
    return if($^S);
    
    $Log::Log4perl::caller_depth++;
    LOGDIE @_;
};


#
# Load database
#

DEBUG "Loading database";

# Check configuration
LOGDIE "Please define a DBD URI to use"
    unless(defined $config_database->{uri});

# Configure database
my $dbh = DBIx::Log4perl->connect($config_database->{uri}, $config_database->{username}, $config_database->{password}, {
    RaiseError  => 1,
    PrintError  => 0,
    AutoCommit  => 1
});


#
# Load harvester
#

DEBUG "Loading harvester";

# Configure harvester
my $harvester = new WWW::IRail::Harvester(
    %{$config_harvester},
    dbh                 => $dbh,
    stations            => \@stationlist
);


#
# Load announcer
#

DEBUG "Loading announcer";

# Configure announcer
my $announcer = new WWW::IRail::DelayAnnouncer(
    %{$config_announcer},
    dbh                 => $dbh,
    harvester_storage   => $harvester->storage(),
    stations            => \@stationlist
);



###############################################################################
# Main
#

INFO "Entering main loop";

while (1) {
    DEBUG "Activating the harvester";
    $harvester->work();
    
    DEBUG "Activating the announcer";
    $announcer->work();
    
    DEBUG "Sleeping...";
    sleep($config_root->{delay});
}

exit(0);


###############################################################################
# Routines
#

sub quit {
    INFO "Closing down";
    
    $dbh->disconnect()
            or WARN "Could not disconnect database: $DBI::errstr";
    
    INFO "Bye...";
    exit(0);
}


###############################################################################
# Documentation
#

=pod

=head1 COPYRIGHT

Copyright 2011 The iRail development team as listed in the AUTHORS file.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
