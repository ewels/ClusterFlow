#!/usr/bin/env perl
use warnings;
use strict;
use Getopt::Long;
use FindBin qw($Bin);
use lib "$FindBin::Bin/../source";
use CF::Constants;
use CF::Helpers;
use File::Copy qw(move);

##########################################################################
# Copyright 2014, Philip Ewels (phil.ewels@scilifelab.se)                #
#                                                                        #
# This file is part of Cluster Flow.                                     #
#                                                                        #
# Cluster Flow is free software: you can redistribute it and/or modify   #
# it under the terms of the GNU General Public License as published by   #
# the Free Software Foundation, either version 3 of the License, or      #
# (at your option) any later version.                                    #
#                                                                        #
# Cluster Flow is distributed in the hope that it will be useful,        #
# but WITHOUT ANY WARRANTY; without even the implied warranty of         #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          #
# GNU General Public License for more details.                           #
#                                                                        #
# You should have received a copy of the GNU General Public License      #
# along with Cluster Flow.  If not, see <http://www.gnu.org/licenses/>.  #
##########################################################################


# Get Options
my $required_cores;
my $required_mem;
my $required_modules;
my $run_fn;
my $help;
my $result = GetOptions ("cores=i" => \$required_cores, "mem=s" => \$required_mem, "modules" => \$required_modules, "runfn=s" => \$run_fn, "help" => \$help);

# QSUB SETUP
# --cores i = offered cores. Return number of required cores.
if($required_cores){
	print 1;
	exit;
}
# --mem. Return the required memory allocation.
if($required_mem){
	print '100M';
	exit;
}
# --modules. Return csv names of any modules which should be loaded.
if($required_modules){
	print 'bismark';
	exit;
}
# --help. Print help.
if($help){
	print "".("-"x21)."\n Bismark Report Module\n".("-"x21)."\n
This script runs the bismark2report script to generate an
overview report. It will run on everything in the directory,
overwriting previously generated reports.\n
For further information, please run bismark2report --help\n\n";
	exit;
}

# MODULE
# Read in the input files from the run file
my ($files, $runfile, $job_id, $prev_job_id, $cores, $mem, $parameters, $config_ref) = CF::Helpers::load_runfile_params(@ARGV);
my %config = %$config_ref;

# --version. Returns version information about the module.
warn "---------- bismark2report version information ----------\n";
warn `bismark2report --version`;
warn "\n------- End of bismark2report version information ------\n";	

if(!system ("bismark2report")){
	warn "###CF Bismark report successfully created\n";
} else {
	warn "###CF Error! Bismark report exited with an error state: $? $!\n";
}