#!/usr/bin/env perl

use Module::Build;

my $build = Module::Build->new (
    module_name         => 'WWW::IRail::DelayAnnouncer',
    dist_name           => 'WWW::IRail::DelayAnnouncer',
    dist_version        => '0.1',
    dist_author         => 'Tim Besard <tim.besard@gmail.com>',
    dist_abstract       => 'The iRail delay announcer',
    license             => 'artistic_2',
    requires            => {
        'perl'              	=> 5,
        'Moose'		        		=> '0.26',
        'LWP::UserAgent'			=> 0,
        'JSON'      	    		=> 0,
        'URI:Escape'        	=> 0,
        'DBI'               	=> 0,
        'File::Find'        	=> 0,
        'Clone'            	  => 0,
        'Log::Log4perl'    	  => 0,
        'DBIx::Log4perl'    	=> 0,
        'List::Util'					=> 0,
        'Config::Tiny'				=> 0,
        'Lingua::EN::Inflect'	=> 0
    },
    recommends => {
    }
);
$build->create_build_script;

