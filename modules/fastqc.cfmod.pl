#!/usr/bin/env perl
use warnings;
use strict;
use Getopt::Long;
use FindBin qw($Bin);
use lib "$FindBin::Bin/../source";
use CF::Constants;
use CF::Helpers;

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
	print '2G';
	exit;
}
# --modules. Return csv names of any modules which should be loaded.
if($required_modules){
	print 'fastqc';
	exit;
}
# --help. Print help.
if($help){
	print "".("-"x15)."\n FastQC Module\n".("-"x15)."\n
FastQC is a quality control tool for high throughput sequence data.
For further information, please run fastqc --help\n\n";
	exit;
}

# MODULE
my $timestart = time;

# Read in the input files from the run file
my ($files, $runfile, $job_id, $prev_job_id, $cores, $mem, $parameters, $config_ref) = CF::Helpers::load_runfile_params(@ARGV);
my %config = %$config_ref;

open (RUN,'>>',$runfile) or die "###CF Error: Can't write to $runfile: $!";

# Print version information about the module.
warn "---------- FastQC version information ----------\n";
warn `fastqc --version`;
warn "\n------- End of FastQC version information ------\n";	

# Read any options from the pipeline parameters
my $nogroup = "";
foreach my $parameter (@$parameters){
	if($parameter eq "nogroup"){
		$nogroup = "--nogroup";
	}
}


# Go through each supplied file and run FastQC.
foreach my $file (@$files){
	
	my $command = "fastqc -q $nogroup $file";
	warn "\n###CFCMD $command\n\n";
	
	if(!system ($command)){
		print RUN "$job_id\t$file\n";
		my $duration =  CF::Helpers::parse_seconds(time - $timestart);
		warn "###CF FastQC successfully ran, took $duration\n";
	} else {
		print "###CF Error! FastQC Failed for input file '$file': $? $!\n";
	}
}

close (RUN);
