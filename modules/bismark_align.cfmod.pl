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
	print CF::Helpers::allocate_cores($required_cores, 4, 8);
	exit;
}
# --mem. Return the required memory allocation.
if($required_mem){
	print CF::Helpers::allocate_memory($required_mem, '13G', '20G');
	exit;
}
# --modules. Return csv names of any modules which should be loaded.
if($required_modules){
	print 'bowtie,bowtie2,bismark,samtools';
	exit;
}
# --help. Print help.
if($help){
	print "".("-"x22)."\n Bismark Align Module\n".("-"x22)."\n
The bismark_align module runs the main bismark script.
Bismark is a program to map bisulfite treated sequencing reads
to a genome of interest and perform methylation calls.\n
PBAT, single cell and Bowtie 1/2 modes can be specified in 
pipelines with the pbat, single_cell bt1 and bt2 parameters. For example:
  #bismark_align	pbat2
  #bismark_align	bt1\n
  #bismark_align	bt2\n
  #bismark_align	single_cell\n
Use bismark --help for further information.\n\n";
	exit;
}

# MODULE
my $timestart = time;

# Read in the input files from the run file
my ($files, $runfile, $job_id, $prev_job_id, $cores, $mem, $parameters, $config_ref) = CF::Helpers::load_runfile_params(@ARGV);
my %config = %$config_ref;

# Check that we have a genome defined
if(!defined($config{references}{fasta})){
   die "\n\n###CF Error: No genome fasta path found in run file $runfile for job $job_id. Exiting.. ###";
} else {
    warn "\nAligning against ".$config{references}{fasta}."\n\n";
}

open (RUN,'>>',$runfile) or die "###CF Error: Can't write to $runfile: $!";

# Print version information about the module.
warn "---------- Bismark version information ----------\n";
warn `bismark --version`;
warn "\n------- End of Bismark version information ------\n";	

# Separate file names into single end and paired end
my ($se_files, $pe_files) = CF::Helpers::is_paired_end(\%config, @$files);

# FastQ encoding type. Once found on one file will assume all others are the same
my $encoding = 0;

# Read any options from the pipeline parameters
my $bt1;
my $bt2 = "";
my $pbat = "";
my $non_directional = "";
foreach my $parameter (@$parameters){
	if($parameter eq "pbat"){
		$pbat = "--pbat";
	}
	if($parameter eq "bt1"){
		$bt1 = 1;
		$bt2 = "";
	} elsif($parameter eq "bt2"){
		$bt2 = "--bowtie2";
	}
	if($parameter eq "single_cell"){
		$non_directional = "--non_directional ";
		$bt2 = "--bowtie2";
	}
}

# Work out whether we should use bowtie 1 or 2 by read length
if(!$bt1 && !$bt2){
	if(!CF::Helpers::fastq_min_length($files->[0], 75)){
		warn "First file has reads < 75bp long. Using bowtie 1 for aligning with bismark.\n";
		$bt1 = 1;
		$bt2 = "";
	} else {
		warn "First file has reads >= 75bp long. Using bowtie 2 for aligning with bismark.\n";
		$bt1 = 0;
		$bt2 = "--bowtie2";
	}
}


# Go through each single end files and run Bismark
if($se_files && scalar(@$se_files) > 0){
	foreach my $file (@$se_files){
		
		# Figure out the encoding if we don't already know
		if(!$encoding){
			($encoding) = CF::Helpers::fastq_encoding_type($file);
		}
		my $enc = "";
		if($encoding eq 'phred33' || $encoding eq 'phred64' || $encoding eq 'solexa'){
			$enc = '--'.$encoding.'-quals';
		}
		
		my $output_fn;
		if($bt2){
			$output_fn = $file."_bismark_bt2.bam";
		} else {
			$output_fn = $file."_bismark.bam";
		}
		
		my $command = "bismark --bam $bt2 $pbat $non_directional $enc ".$config{references}{fasta}." ".$file;
		warn "\n###CFCMD $command\n\n";
		
		if(!system ($command)){
			# Bismark worked - print out resulting filenames
			my $duration =  CF::Helpers::parse_seconds(time - $timestart);
			warn "\n###CF Bismark (SE mode) successfully exited, took $duration..\n";
			if(-e $output_fn){
				print RUN "$job_id\t$output_fn\n"; 
			} else {
				warn "\n###CF Error! Bismark output file $output_fn not found..\n";
			}
		} else {
			die "\n###CF Error! Bismark alignment (SE mode) exited with an error state for file '$file': $? $!\n\n";
		}
	}
}

# Go through the paired end files and run Bismark
if($pe_files && scalar(@$pe_files) > 0){
	foreach my $files_ref (@$pe_files){
		my @files = @$files_ref;
		if(scalar(@files) == 2){
			
			# Figure out the encoding if we don't already know
			if(!$encoding){
				($encoding) = CF::Helpers::fastq_encoding_type($files[0]);
			}
			my $enc = "";
			if($encoding eq 'phred33' || $encoding eq 'phred64' || $encoding eq 'solexa'){
				$enc = '--'.$encoding.'-quals';
			}
			
			my $output_fn;
			if(length($bt2) > 0){
				$output_fn = $files[0]."_bismark_bt2_pe.bam";
			} else {
				$output_fn = $files[0]."_bismark_pe.bam";
			}
			
			my $command = "bismark --bam $bt2 $pbat $non_directional $enc ".$config{references}{fasta}." -1 ".$files[0]." -2 ".$files[1];
			warn "\n###CFCMD $command\n\n";
			
			if(!system ($command)){
				# Bismark worked - print out resulting filenames
				my $duration =  CF::Helpers::parse_seconds(time - $timestart);
				warn "\n###CF Bismark (PE mode) successfully exited, took $duration..\n";
				if(-e $output_fn){
					print RUN "$job_id\t$output_fn\n";
				} else {
					warn "\n###CF Error! Bismark output file $output_fn not found..\n";
				}
			} else {
				die "\n###CF Error! Bismark alignment (PE mode) exited with an error state for file '".$files[0]."': $? $!\n\n";
			}
		} else {
			warn "\n###CF Error! Bismark paired end files had ".scalar(@files)." input files instead of 2..\n";
		}
	}
}


close (RUN);
