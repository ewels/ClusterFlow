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
	print '500M';
	exit;
}
# --modules. Return csv names of any modules which should be loaded.
if($required_modules){
	print 'sratoolkit';
	exit;
}
# --help. Print help.
if($help){
	print "".("-"x23)."\n SRA SOLiD Dump Module\n".("-"x23)."\n
This module uses the sra toolkit abi-dump package
to extract  csqual and csfasta files from .sra input.\n\n";
	exit;
}

# MODULE
# Read in the input files from the run file
my ($files, $runfile, $job_id, $prev_job_id, $cores, $mem, $parameters, $config_ref) = CF::Helpers::load_runfile_params(@ARGV);
my %config = %$config_ref;

open (RUN,'>>',$runfile) or die "###CF Error: Can't write to $runfile: $!";

# Print version information about the module.
warn "---------- ABI Dump version information ----------\n";
warn `abi-dump --version`;
warn "\n------- End of ABI Dump version information ------\n";	

# Go through each supplied file and run abi-dump.
foreach my $file (@$files){

	my $fn_base = substr($file, 0, -4);
	my @outputfiles = ($fn_base."_F3.csfasta.gz", $fn_base."_F3_QV.qual.gz");
	
	for (my $attempt = 1; $attempt < 6; $attempt++) {
		
		my $command = "abi-dump --gzip ./$file";
		warn "\n###CFCMD $command\n\n";
		
		if(!system ($command)){
			warn "\n###CF SOLiD Dump successfully exited on attempt $attempt\n";
			# SOLiD Dump worked - print out resulting filenames
			foreach my $output_fn (@outputfiles){
				if(-e $output_fn){
					print RUN "$job_id\t$output_fn\n";
				} else {
					warn "\n###CF Error! SRA dump files $output_fn not found..\n\n";
				}
			}
			last;
			
		} else {
			
			# SOLiD Dump failed - clean up partially dumped files
			foreach my $output_fn (@outputfiles){
				if(-e $output_fn){
					unlink $output_fn or die "Could not delete $output_fn : $!";
				}
			}
			warn "###CF Error! SOLiD Dump failed on attempt $attempt for input file '$file': $? $!\n";
			
		}
	}
}

close (RUN);