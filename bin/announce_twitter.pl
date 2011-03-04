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


###############################################################################
# Main
#

#
# Load command-line parameters
#

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

# Read config
my $config = Config::Tiny->read($params{config})
    or die("Could not read the configuration file at $params{config}: $!");

# Create some section objects
my $config_root = $config->{_};
my $config_twitter = $config->{twitter};


#
# Setup twitter
#

# Check consumer key
if (!defined $config_twitter || grep { !defined $config_twitter->{$_} } qw/consumer_key consumer_secret/) {
    die("Twitter consumer configuration missing, please register an application at <https://dev.twitter.com/apps/new>");
}

my $nt = Net::Twitter->new(
    traits              => [qw/API::REST OAuth/],
    consumer_key        => $config_twitter->{consumer_key},
    consumer_secret     => $config_twitter->{consumer_secret}
);

# Check access key
if (grep { !defined $config_twitter->{$_} } qw/access_token access_token_secret/) {
    print "Authorize this app at ", $nt->get_authorization_url, " and enter the PIN#\n";

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
    die("Application authorization failed, please verify the keys and secrets");
}


#
# Load database
#

die("Please define a database to use")
    unless(defined $config_root->{database});

my $database = new WWW::IRail::DelayAnnouncer::Database(uri => $config_root->{database});

if ($params{init}) {
    print "Creating database...\n";
    $database->create();
}


#
# Start announcer
#

die("Please define a station to use")
    unless(defined $config_root->{station});

my $announcer = new WWW::IRail::DelayAnnouncer(station => $config_root->{station}, database => $database);
$announcer->add_notifier(sub {
    my ($message) = @_;
    print "Tweeting: $message\n";
});
$announcer->run();


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
