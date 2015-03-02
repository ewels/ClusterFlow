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
	print CF::Helpers::allocate_memory($required_mem, '3G', '30G');
	exit;
}
# --modules. Return csv names of any modules which should be loaded.
if($required_modules){
	print 'bismark';
	exit;
}
# --help. Print help.
if($help){
	print "".("-"x28)."\n Bismark Deduplicate Module\n".("-"x28)."\n
The bismark_deduplicate module runs the deduplicate_bismark script.
This removes alignments to the same position in the genome from the
Bismark mapping output which can arise by e.g. excessive PCR amplification.\n
For further information please run deduplicate_bismark --help \n\n";
	exit;
}

# MODULE
my $timestart = time;

# Read in the input files from the run file
my ($files, $runfile, $job_id, $prev_job_id, $cores, $mem, $parameters, $config_ref) = CF::Helpers::load_runfile_params(@ARGV);
my %config = %$config_ref;

open (RUN,'>>',$runfile) or die "###CF Error: Can't write to $runfile: $!";

# Print version information about the module.
warn "---------- deduplicate_bismark version information ----------\n";
warn `deduplicate_bismark --version`;
warn "\n------- End of deduplicate_bismark version information ------\n";	

# Go through each file and deduplicate
if($files && scalar(@$files) > 0){
	foreach my $file (@$files){
		
		my $output_fn = substr($file,0 ,-3)."deduplicated.bam";
		
		# Find if PE or SE from input BAM file
		if(CF::Helpers::is_bam_paired_end($file)){
			
			my $command = "deduplicate_bismark -p --bam $file";
			warn "\n###CFCMD $command\n\n";
			
			# Paired End BAM file
			if(!system ($command)){
				# Bismark worked - print out resulting filenames
				my $duration =  CF::Helpers::parse_seconds(time - $timestart);
				warn "###CF Bismark deduplication (PE mode) successfully exited, took $duration..\n";
				if(-e $output_fn){
					print RUN "$job_id\t$output_fn\n"; 
				} else {
					warn "\n###CF Error! Bismark output file $output_fn not found..\n";
				}
			} else {
				warn "\n###CF Error!Bismark deduplication (PE mode) exited with an error state for file '$file': $? $!\n\n";
			}
			
		} else {
			
			my $command = "deduplicate_bismark -s --bam $file";
			warn "\n###CFCMD $command\n\n";
			
			# Single End BAM file
			if(!system ($command)){
				# Bismark worked - print out resulting filenames
				my $duration =  CF::Helpers::parse_seconds(time - $timestart);
				warn "###CF Bismark deduplication (SE mode) successfully exited, took $duration..\n";
				if(-e $output_fn){
					print RUN "$job_id\t$output_fn\n"; 
				} else {
					warn "\n###CF Error! Bismark output file $output_fn not found..\n";
				}
			} else {
				warn "\n###CF Error! Bismark deduplication (SE mode) exited with an error state for file '$file': $? $!\n\n";
			}
			
		}
	}
}


close (RUN);