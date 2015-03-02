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
    print CF::Helpers::allocate_cores($required_cores, 1, 8);
    exit;
}
# --mem. Return the required memory allocation.
if($required_mem){
    print CF::Helpers::allocate_memory($required_mem, '3G', '4G');
    exit;
}
# --modules. Return csv names of any modules which should be loaded.
if($required_modules){
    print 'bwa,samtools';
    exit;
}
# --help. Print help.
if($help){
    print "".("-"x17)."\n BWA Module\n".("-"x17)."\n
BWA (Burrows-Wheeler Alignment Tool) is a software package for mapping
low-divergent sequences against a large reference genome, such as the
human genome. The BWA-MEM algorithm is used in this module.

The module needs a reference of type bwa.
\n\n";
    exit;
}

# MODULE
my $timestart = time;

# Read in the input files from the run file
my ($files, $runfile, $job_id, $prev_job_id, $cores, $mem, $parameters, $config_ref) = CF::Helpers::load_runfile_params(@ARGV);
my %config = %$config_ref;

# Check that we have a genome defined
if(!defined($config{references}{bwa})){
    die "\n\n###CF Error: No BWA index path found in run file $runfile for job $job_id. Exiting.. ###";
} else {
    warn "\nAligning against ".$config{references}{bwa}."\n\n";
}

if(!defined($cores) || $cores <= 0){
    $cores = 1;
}

open (RUN,'>>',$runfile) or die "###CF Error: Can't write to $runfile: $!";

# Print version information about the module.
warn "---------- BWA version information ----------\n";
warn `bwa 2>&1 | head -n 5`;
warn "\n------- End of BWA version information ------\n";  

# Separate file names into single end and paired end
my ($se_files, $pe_files) = CF::Helpers::is_paired_end(\%config, @$files);


# Go through each single end files and run BWA
if($se_files && scalar(@$se_files) > 0){
	foreach my $file (@$se_files){
		
        my $output_fn = $file."_bwa.bam";
        
		my $command = "bwa mem -t $cores ".$config{references}{bwa}." $file | samtools view -bS - > $output_fn";
		warn "\n###CFCMD $command\n\n";
		
		if(!system ($command)){
			# BWA worked - print out resulting filenames
			my $duration =  CF::Helpers::parse_seconds(time - $timestart);
			warn "###CF BWA (SE mode) successfully exited, took $duration..\n";
			if(-e $output_fn){
				print RUN "$job_id\t$output_fn\n"; 
			} else {
				warn "\n###CF Error! BWA output file $output_fn not found..\n";
			}
		} else {
			warn "\n###CF Error! BWA (SE mode) exited in an error state for input file '$file': $? $!\n\n";
		}
	}
}

# Go through the paired end files and run BWA
if($pe_files && scalar(@$pe_files) > 0){
	foreach my $files_ref (@$pe_files){
		my @files = @$files_ref;
		if(scalar(@files) == 2){
			
            my $output_fn = $files[0]."_bwa.bam";
        
    		my $command = "bwa mem -t $cores ".$config{references}{bwa}." $files[0] $files[1] | samtools view -bS - > $output_fn";
    		warn "\n###CFCMD $command\n\n";
		
    		if(!system ($command)){
    			# BWA worked - print out resulting filenames
    			my $duration =  CF::Helpers::parse_seconds(time - $timestart);
    			warn "###CF BWA (PE mode) successfully exited, took $duration..\n";
    			if(-e $output_fn){
    				print RUN "$job_id\t$output_fn\n"; 
    			} else {
    				warn "\n###CF Error! BWA output file $output_fn not found..\n";
    			}
    		} else {
    			warn "\n###CF Error! BWA (PE mode) exited in an error state for input file '$files[0]': $? $!\n\n";
    		}
			
		} else {
			warn "\n###CF Error! BWA paired end files had ".scalar(@files)." input files instead of 2\n";
		}
	}
}


close (RUN);
