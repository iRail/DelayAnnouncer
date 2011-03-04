#!/usr/bin/env perl
#
# iRail delay announcer - Twitter interface
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
use Net::Twitter;
use Getopt::Long;
use Pod::Usage;
use WWW::IRail::DelayAnnouncer;
use WWW::IRail::DelayAnnouncer::Database;
use Log::Log4perl qw(:easy);

# Initial logging
Log::Log4perl->easy_init($INFO);

# Signal handling
$SIG{INT} = "quit";
$SIG{TERM} = "quit";


###############################################################################
# Main
#

#
# Load command-line parameters
#

INFO "Initialising";
DEBUG "Loading command-line parameters";

# Register variables
my %params;
$params{config} = "twitter.ini";

# Load
GetOptions(
    \%params,
    "config|c=s",
    "help|h",
    "man",
    "init"
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
my $config_root = $config->{_};
my $config_twitter = $config->{twitter}
    or LOGDIE "Twitter configuration section missing";
my $config_log = $config->{log}
    or LOGDIE "Log configuration section missing";


#
# Load logging
#

DEBUG "Loading logging";

LOGDIE "Please specify a logging type"
    unless (defined $config_log->{type});

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
# Load Twitter
#

DEBUG "Loading Twitter";

# Check consumer key
if (!defined $config_twitter || grep { !defined $config_twitter->{$_} } qw/consumer_key consumer_secret/) {
    LOGDIE "Twitter consumer configuration missing, please register an application at <https://dev.twitter.com/apps/new>";
}

my $nt = Net::Twitter->new(
    traits              => [qw/API::REST OAuth/],
    consumer_key        => $config_twitter->{consumer_key},
    consumer_secret     => $config_twitter->{consumer_secret}
);

# Check access key
if (grep { !defined $config_twitter->{$_} } qw/access_token access_token_secret/) {
    INFO "Authorize this app at ", $nt->get_authorization_url, " and enter the PIN number";

    my $pin = <STDIN>; # wait for input
    chomp $pin;

    my ($access_token, $access_token_secret, $user_id, $screen_name) = $nt->request_access_token(verifier => $pin);
    
    $config_twitter->{access_token} = $access_token;
    $config_twitter->{access_token_secret} = $access_token_secret;
    $config->write($params{config});
}

$nt->access_token($config_twitter->{access_token});
$nt->access_token_secret($config_twitter->{access_token_secret});

unless ($nt->authorized) {
    LOGDIE "Application authorization failed, please verify the keys and secrets";
}


#
# Load database
#

DEBUG "Loading database";

LOGDIE "Please define a database to use"
    unless(defined $config_root->{database});

my $database = new WWW::IRail::DelayAnnouncer::Database(uri => $config_root->{database});

if ($params{init}) {
    DEBUG "Creating database";
    $database->create();
}


#
# Load announcer
#

DEBUG "Loading announcer";

LOGDIE "Please define a station to use"
    unless (defined $config_root->{station});

LOGDIE "Please provide station coordinates"
    unless (defined $config_root->{longitude} && defined $config_root->{latitude});

my $announcer = new WWW::IRail::DelayAnnouncer(station => $config_root->{station}, database => $database);
$announcer->add_listener(sub {
    my ($message) = @_;
    INFO "Tweeting: $message";
    $nt->update({
        status                  => $message,
        long                    => $config_root->{longitude},
        lat                     => $config_root->{latitude},
        display_coordinates     => 1
    });
});

INFO "Starting announcer";
$announcer->run();

exit(0);


###############################################################################
# Routines
#

sub quit {
    INFO "Closing down";
    $database->close();
    
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
