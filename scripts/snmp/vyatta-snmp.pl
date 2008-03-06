#!/usr/bin/perl
#
# Module: vyatta-snmp.pl
# 
# **** License ****
# Version: VPL 1.0
# 
# The contents of this file are subject to the Vyatta Public License
# Version 1.0 ("License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://www.vyatta.com/vpl
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
# 
# This code was originally developed by Vyatta, Inc.
# Portions created by Vyatta are Copyright (C) 2007 Vyatta, Inc.
# All Rights Reserved.
# 
# Author: Stig Thormodsrud
# Date: October 2007
# Description: Script to glue vyatta cli to snmp daemon
# 
# **** End License ****
#

use lib "/opt/vyatta/share/perl5/";
use VyattaConfig;
use VyattaMisc;
use Getopt::Long;

use strict;
use warnings;

my $mibdir    = '/opt/vyatta/share/snmp/mibs';
my $snmp_init = '/opt/vyatta/sbin/snmpd.init';
my $snmp_conf = '/etc/snmp/snmpd.conf';


sub snmp_init {
    #
    # This requires the iptables user module libipt_rlsnmpstats.so.
    # to get the stats from "show snmp".  For now we are disabling
    # this feature.
    #

    # system("iptables -A INPUT -m rlsnmpstats");
    # system("iptables -A OUTPUT -m rlsnmpstats");
}

sub snmp_restart {
    system("$snmp_init restart");
}

sub snmp_stop {
    system("$snmp_init stop");
}

sub snmp_get_constants {
    my $output;
    
    my $date = `date`;
    chomp $date;
    $output  = "#\n# autogenerated by vyatta-snmp.pl on $date\n#\n";
    $output .= "trap2sink localhost vyatta 51510\n";
    $output .= "sysServices 14\n";
    return $output;
}

sub snmp_get_values {
    my $output = '';
    my $config = new VyattaConfig;

    $config->setLevel("protocols snmp community");
    my @communities = $config->listNodes();
    
    foreach my $community (@communities) {
	my $authorization = $config->returnValue("$community authorization");
	if (defined $authorization and $authorization eq "rw") {
	    $output .= "rwcommunity $community\n";
	} else {
	    $output .= "rocommunity $community\n";
	}
    }

    $config->setLevel("protocols snmp");
    my $contact = $config->returnValue("contact");
    if (defined $contact) {
	$output .= "syscontact \"$contact\" \n";
    }
    my $description = $config->returnValue("description");
    if (defined $description) {
	$output .= "sysdescr \"$description\" \n";
    }
    my $location = $config->returnValue("location");
    if (defined $location) {
	$output .= "syslocation \"$location\" \n";
    }

    my @trap_targets = $config->returnValues("trap-target"); 
    foreach my $trap_target (@trap_targets) {
	$output .= "trapsink $trap_target\n";
    }

    return $output;
}

sub snmp_write_file {
    my ($config) = @_;

    open(my $fh, '>', $snmp_conf) || die "Couldn't open $snmp_conf - $!";
    print $fh $config;
    close $fh;
}


#
# main
#
my $init_snmp;
my $update_snmp;
my $stop_snmp;

GetOptions("init-snmp!"   => \$init_snmp,
	   "update-snmp!" => \$update_snmp,
           "stop-snmp!"   => \$stop_snmp);

if (defined $init_snmp) {
    snmp_init();
}

if (defined $update_snmp) { 
    my $config;

    $config  = snmp_get_constants();
    $config .= snmp_get_values();
    snmp_write_file($config);
    snmp_restart();
}

if (defined $stop_snmp) {
    snmp_stop();
}

exit 0;

# end of file




