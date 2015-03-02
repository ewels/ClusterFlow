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
	print CF::Helpers::allocate_cores($required_cores, 2, 4);
	exit;
}
# --mem. Return the required memory allocation.
if($required_mem){
    print CF::Helpers::allocate_memory($required_mem, '8G', '30G');	
}
# --modules. Return csv names of any modules which should be loaded.
if($required_modules){
	print 'samtools';
	exit;
}
# --help. Print help.
if($help){
	print "".("-"x25)."\n Samtools Index Module\n".("-"x25)."\n
Indexes a BAM file. Index <input>.bai files are written to disk, but
input file names are written to the Cluster Flow run file for
downstream modules.\n";
	exit;
}

# MODULE
my $timestart = time;

# Read in the input files from the run file
my ($files, $runfile, $job_id, $prev_job_id, $cores, $mem, $parameters, $config_ref) = CF::Helpers::load_runfile_params(@ARGV);
my %config = %$config_ref;
$mem = CF::Helpers::human_readable_to_bytes($mem);
my $mem_per_thread = int($mem/$cores);
warn "\n\n Samtools: mem per thread: $mem_per_thread ; cores: $cores\n\n\n";

if(!defined($cores) or $cores < 1){
	$cores = 1;
}

open (RUN,'>>',$runfile) or die "###CF Error: Can't write to $runfile: $!";

# Print version information about the module.
 warn "---------- Samtools version information ----------\n";
 warn `samtools 2>&1 | head -n 4`;
 warn "\n------- End of Samtools version information ------\n";	

# we want e.g. samtools view -bS ./input.sam | samtools sort - outfile
if($files && scalar(@$files) > 0){
	foreach my $file (@$files){
	
		my $command = "samtools index $file";
		warn "\n###CFCMD $command\n\n";
	
		if(!system ($command)){
			# samtools worked - print out resulting filenames
			my $duration =  CF::Helpers::parse_seconds(time - $timestart);
			warn "###CF samtools index successfully exited, took $duration..\n";
			print RUN "$job_id\t$file\n";
			unless (-e "$file.bai"){
				warn "\n###CF Error! samtools index output file $file.bai not found..\n";
			}
			
		} else {
			warn "\n###CF Error! samtools index failed, exited in an error state: $? $!\n\n";
		}
	}
}



close (RUN);
